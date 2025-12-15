module tl_hdr_gen
import tl_pkg::*;
 #(
  parameter int TAG_W             = 8,
  parameter int MAX_PAYLOAD_BYTES = 256,
  parameter int PH_WIDTH          = 8,
  parameter int PD_WIDTH          = 12,
  parameter int NPH_WIDTH         = 8,
  parameter int NPD_WIDTH         = 12
)(
  input  logic                   clk,
  input  logic                   rst_n,

  input [15:0]                  REQUESTER_ID, // Requester ID for commands

  // User command channel
  input  tl_cmd_t                cmd_i,
  input  logic                   cmd_valid_i,
  output logic                   cmd_ready_o,

  // Allocated tag from Tag Table
  input  logic [TAG_W-1:0]       tag_i,
  input  logic                   tag_valid_i,
  output logic                   tag_consume_o,

  output logic [63:0]            tag_addr_o,  // Address associated with tag
  output logic [9:0]             tag_len_o,   // Length in DWs associated with tag
  output logic [2:0]             tag_attr_o,  // Attributes associated with tag
  output logic [4:0]             tag_pkt_type_o, // Packet type associated with tag
  output logic [2:0]             tag_fmt_o,      // Format associated with tag
  output logic [3:0]             tag_first_be_o, // First byte enable
  output logic [3:0]             tag_last_be_o,  // Last byte enable

  output logic [7:0]             tag_bus_number_o, // Bus number associated with tag
  output logic [4:0]             tag_device_number_o, // Device number associated with tag
  output logic [2:0]             tag_function_number_o, // Function number associated with tag


  // Generated Header out
  output logic [127:0]           hdr_o,
  output logic                   hdr_valid_o,
  input  logic                   hdr_ready_i
);
  // FSM states
typedef enum logic [2:0] {
  FSM_IDLE,
  FSM_DECODE,
  FSM_WAIT_TAG,
  FSM_GEN_HDR,
  FSM_SEND_HDR,
  FSM_UNSUPPORTED   // <-- new state
} fsm_e;


  fsm_e fsm_state, fsm_next;
  logic [TAG_W-1:0] cmd_tag_reg;
  tl_cmd_t cmd_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fsm_state <= FSM_IDLE;
    end else begin
        fsm_state <= fsm_next;
    end
end

always_comb begin
    fsm_next = fsm_state;
    case (fsm_state)
        FSM_IDLE: begin
            if (cmd_valid_i) begin
                fsm_next = FSM_DECODE;
            end
        end
        FSM_DECODE: begin
            if ((cmd_reg.type_cmd == CMD_MEM && !cmd_reg.wr_en) || cmd_reg.type_cmd == CMD_CFG) begin
                fsm_next = FSM_WAIT_TAG;
            end else if(cmd_reg.type_cmd == CMD_MEM && cmd_reg.wr_en) begin
                fsm_next = FSM_GEN_HDR;
            end else begin
                fsm_next = FSM_UNSUPPORTED; // Unsupported command type
            end
        end
        FSM_WAIT_TAG: begin
            if (tag_valid_i) begin
                fsm_next = FSM_GEN_HDR;
            end
        end
        FSM_GEN_HDR: begin
            fsm_next = FSM_SEND_HDR;
        end
        FSM_SEND_HDR: begin
            if (hdr_valid_o && hdr_ready_i) begin
                fsm_next = FSM_IDLE;
            end
        end
        FSM_UNSUPPORTED: begin
            fsm_next = FSM_IDLE; //simply go back to IDLE on next cycle
        end
        default: fsm_next = FSM_IDLE;
    endcase
end

/*    Header format (16 bytes):
    [127:120]  Fmt/Type
    [119:112]  TC/Reserved
    [111:96]   Length (in DW)
    [95:64]    Requester ID (Bus/Device/Function)
    [63:56]    Tag
    [55:48]    Last DW BE / First DW BE
    [47:32]    Address (31:16)
    [15:2]     Address (15:2)
    [1:0]      Reserved
    For 64-bit address, add another 4 bytes for Address (63:32)
*/
always_comb begin
    if(fsm_state == FSM_IDLE) begin
        cmd_ready_o <= 1'b1;
    end else begin
        cmd_ready_o <= 1'b0;
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_reg <= '0;
    end else begin
        if (cmd_valid_i && cmd_ready_o) begin
            cmd_reg <= cmd_i;
        end
    end
end


always_comb begin
    if (!rst_n) begin
        tag_consume_o <= 1'b0;
    end else begin
        if (fsm_state == FSM_WAIT_TAG && tag_valid_i) begin
            tag_consume_o = 1'b1;
        end else begin
            tag_consume_o = 1'b0;
        end
    end
end

always_comb begin
    if (!rst_n) begin
        tag_addr_o = '0;
        tag_len_o  = '0;
        tag_attr_o = '0;
    end else begin
        if (fsm_state == FSM_WAIT_TAG && tag_valid_i) begin
            if(cmd_reg.type_cmd == CMD_MEM) begin
                tag_addr_o = {cmd_reg.addr[63:2], 2'b00};
                tag_len_o  = cmd_reg.len;
                tag_attr_o = 2'b00; // Default attributes, can be 
                if(cmd_reg.wr_en == 1'b1) begin
                    tag_pkt_type_o = 5'b00000; // Memory Write
                    tag_fmt_o      = (cmd_reg.addr[63:32] != 32'h0) ? 3'b010 : 3'b011; // 64-bit or 32-bit
                end else begin
                    tag_pkt_type_o = 5'b00000; // Memory Read
                    tag_fmt_o      = (cmd_reg.addr[63:32] != 32'h0) ? 3'b001 : 3'b000; // 64-bit or 32-bit
                end
                if(cmd_reg.len == 10'd1) begin
                    case (cmd_reg.addr[1:0])
                        2'b00: {tag_last_be_o, tag_first_be_o} <= {4'b0000, 4'b1111};
                        2'b01: {tag_last_be_o, tag_first_be_o} <= {4'b0000, 4'b1110};
                        2'b10: {tag_last_be_o, tag_first_be_o} <= {4'b0000, 4'b1100};
                        2'b11: {tag_last_be_o, tag_first_be_o} <= {4'b0000, 4'b1000};
                        default: {tag_last_be_o, tag_first_be_o} <= {4'b0000, 4'b1111};
                    endcase
                end else begin
                    case (cmd_reg.addr[1:0])
                        2'b00: {tag_last_be_o, tag_first_be_o} <= {4'b1111, 4'b1111};
                        2'b01: {tag_last_be_o, tag_first_be_o} <= {4'b1111, 4'b1110};
                        2'b10: {tag_last_be_o, tag_first_be_o} <= {4'b1111, 4'b1100};
                        2'b11: {tag_last_be_o, tag_first_be_o} <= {4'b1111, 4'b1000};
                        default: {tag_last_be_o, tag_first_be_o} <= {4'b1111, 4'b1111};
                    endcase
                end
                tag_bus_number_o     = 8'b0;
                tag_device_number_o  = 5'b0;
                tag_function_number_o= 3'b0;
            end else if(cmd_reg.type_cmd == CMD_CFG) begin
                if(cmd_reg.wr_en == 1'b1) begin
                    tag_fmt_o = 3'b010; // Config Write
                    tag_pkt_type_o = 5'b00100; // Config Write
                end else begin
                    tag_fmt_o = 3'b000; // Config Read
                    tag_pkt_type_o = 5'b00100; // Config Read
                end
                tag_first_be_o = 4'b1111;
                tag_last_be_o  = 4'b0000;
                tag_addr_o = '0;
                tag_len_o = 10'd1;
                tag_attr_o = 2'b00;
                tag_bus_number_o     = cmd_reg.bus;
                tag_device_number_o  = cmd_reg.device;
                tag_function_number_o = cmd_reg.function_num;
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cmd_tag_reg <= '0;
    end else begin
        if (fsm_state == FSM_WAIT_TAG && tag_valid_i) begin
            cmd_tag_reg <= tag_i;
        end
    end
end



always_ff @(posedge clk or negedge rst_n) begin
    hdr_o <= hdr_o; // default hold value
    if(!rst_n) begin
        hdr_o = '0;
    end
    else if(fsm_state == FSM_GEN_HDR) begin
        if(cmd_reg.type_cmd == CMD_MEM) begin
            if(cmd_reg.addr[63:32] != 32'h0) begin
                // 64-bit address
                if(cmd_reg.wr_en == 1'b1) begin // Write Command
                    hdr_o[7:0]     <= 8'h60;              // Byte 0: Fmt/Type
                    hdr_o[15:8]    <= {4'b0000, 1'b0, 1'b0, 2'b00};
                    hdr_o[23:16]   <= {1'b0, 1'b0, 2'b0, 2'b0, cmd_reg.len[9:8]};
                    hdr_o[31:24]   <= cmd_reg.len[7:0];
                    hdr_o[39:32]   <= REQUESTER_ID[15:8]; // Byte 4: Requester ID (Bus)
                    hdr_o[47:40]   <= REQUESTER_ID[7:0];  // Byte 5: Requester ID (Dev/Func)
                    hdr_o[55:48]   <= 8'h00;              // Byte 6: Tag
                    // Byte 
                    if(cmd_reg.len == 10'd1) begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b0000, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b0000, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b0000, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b0000, 4'b1000};
                            default: hdr_o[63:56] <= {4'b0000, 4'b1111};
                        endcase
                    end else begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b1111, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b1111, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b1111, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b1111, 4'b1000};
                            default: hdr_o[63:56] <= {4'b1111, 4'b1111};
                        endcase
                    end
                    hdr_o[71:64]   <= cmd_reg.addr[63:56];
                    hdr_o[79:72]   <= cmd_reg.addr[55:48];
                    hdr_o[87:80]   <= cmd_reg.addr[47:40];
                    hdr_o[95:88]   <= cmd_reg.addr[39:32];
                    hdr_o[103:96]  <= cmd_reg.addr[31:24];
                    hdr_o[111:104] <= cmd_reg.addr[23:16];
                    hdr_o[119:112] <= cmd_reg.addr[15:8];
                    hdr_o[127:120] <= {cmd_reg.addr[7:2], 2'b00};
                end 
                else begin
                    // Memory Read 64 (Fmt=0b001, Type=0b00000)
                    hdr_o[7:0]     <= 8'h20;                          // Byte 0: Fmt[7:5]=001, Type[4:0]=00000
                    hdr_o[15:8]    <= {4'b0000, 1'b0, 1'b0, 2'b00};
                    hdr_o[23:16]   <= {1'b0, 1'b0, 2'b0, 2'b0, cmd_reg.len[9:8]};
                    hdr_o[31:24]   <= cmd_reg.len[7:0];
                    hdr_o[39:32]   <= REQUESTER_ID[15:8]; // Byte 4: Requester ID (Bus)
                    hdr_o[47:40]   <= REQUESTER_ID[7:0];  // Byte 5: Requester ID (Dev/Func)
                    hdr_o[55:48]   <= cmd_tag_reg;              // Byte 6: Tag (0 for posted writes)
                    if(cmd_reg.len == 10'd1) begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b0000, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b0000, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b0000, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b0000, 4'b1000};
                            default: hdr_o[63:56] <= {4'b0000, 4'b1111};
                        endcase
                    end else begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b1111, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b1111, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b1111, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b1111, 4'b1000};
                            default: hdr_o[63:56] <= {4'b1111, 4'b1111};
                        endcase
                    end
                    hdr_o[71:64]   <= cmd_reg.addr[63:56];
                    hdr_o[79:72]   <= cmd_reg.addr[55:48];
                    hdr_o[87:80]   <= cmd_reg.addr[47:40];
                    hdr_o[95:88]   <= cmd_reg.addr[39:32];
                    hdr_o[103:96]  <= cmd_reg.addr[31:24];
                    hdr_o[111:104] <= cmd_reg.addr[23:16];
                    hdr_o[119:112] <= cmd_reg.addr[15:8];
                    hdr_o[127:120] <= {cmd_reg.addr[7:2], 2'b00};
            end
        end else begin
                // 32-bit address
                if(cmd_reg.wr_en == 1'b1) begin // Write Command
                    hdr_o[7:0]     <= 8'h40;                          // Byte 0: Fmt[7:5]=010, Type[4:0]=00000
                    hdr_o[15:8]    <= {4'b0000, 1'b0, 1'b0, 2'b00};
                    hdr_o[23:16]   <= {1'b0, 1'b0, 2'b0, 2'b0, cmd_reg.len[9:8]};
                    hdr_o[31:24]   <= cmd_reg.len[7:0];
                    hdr_o[39:32]   <= REQUESTER_ID[15:8]; // Byte 4: Requester ID (Bus)
                    hdr_o[47:40]   <= REQUESTER_ID[7:0];  // Byte 5: Requester ID (Dev/Func)
                    hdr_o[55:48]   <= 8'h00;              // Byte 6: Tag (0 for posted writes)
                    if(cmd_reg.len == 10'd1) begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b0000, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b0000, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b0000, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b0000, 4'b1000};
                            default: hdr_o[63:56] <= {4'b0000, 4'b1111};
                        endcase
                    end else begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b1111, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b1111, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b1111, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b1111, 4'b1000};
                            default: hdr_o[63:56] <= {4'b1111, 4'b1111};
                        endcase
                    end
                    hdr_o[71:64]   <= cmd_reg.addr[31:24];            // Byte 8: Address[31:24]
                    hdr_o[79:72]   <= cmd_reg.addr[23:16];            // Byte 9: Address[23:16]
                    hdr_o[87:80]   <= cmd_reg.addr[15:8];             // Byte 10: Address[15:8]
                    hdr_o[95:88]   <= {cmd_reg.addr[7:2], 2'b00};     // Byte 11: Address[7:2], PH[1:0]
                    hdr_o[127:96]  <= 32'h0;
                end else begin
                    // Memory Read 32 (Fmt=0b000, Type=0b00000)
                    hdr_o[7:0]     <= 8'h00;                          // Byte 0: Fmt[7:5]=000, Type[4:0]=00000
                    hdr_o[15:8]    <= {4'b0000, 1'b0, 1'b0, 2'b00};
                    hdr_o[23:16]   <= {1'b0, 1'b0, 2'b0, 2'b0, cmd_reg.len[9:8]};
                    hdr_o[31:24]   <= cmd_reg.len[7:0];
                    hdr_o[39:32]   <= REQUESTER_ID[15:8]; // Byte 4: Requester ID (Bus)
                    hdr_o[47:40]   <= REQUESTER_ID[7:0];  // Byte 5: Requester ID (Dev/Func)
                    hdr_o[55:48]   <= cmd_tag_reg;              // Byte 6: Tag (0 for posted writes)
                    if(cmd_reg.len == 10'd1) begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b0000, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b0000, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b0000, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b0000, 4'b1000};
                            default: hdr_o[63:56] <= {4'b0000, 4'b1111};
                        endcase
                    end else begin
                        case (cmd_reg.addr[1:0])
                            2'b00: hdr_o[63:56] <= {4'b1111, 4'b1111};
                            2'b01: hdr_o[63:56] <= {4'b1111, 4'b1110};
                            2'b10: hdr_o[63:56] <= {4'b1111, 4'b1100};
                            2'b11: hdr_o[63:56] <= {4'b1111, 4'b1000};
                            default: hdr_o[63:56] <= {4'b1111, 4'b1111};
                        endcase
                    end
                    hdr_o[71:64]   <= cmd_reg.addr[31:24];
                    hdr_o[79:72]   <= cmd_reg.addr[23:16];
                    hdr_o[87:80]   <= cmd_reg.addr[15:8];
                    hdr_o[95:88]   <= {cmd_reg.addr[7:2], 2'b00};
                    hdr_o[127:96]  <= 32'h0;
                end
            end
        end
        else if(cmd_reg.type_cmd == CMD_CFG) begin
            if(cmd_reg.wr_en == 1'b1) begin
                hdr_o[7:0] <= 8'b010_00100; // Config Write Type 0
                hdr_o[15:8]    <= {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0}; // Byte 1: R, TC[2:0]=000, R, Attr[2]=0, R, TH
                hdr_o[23:16] <= {1'b0, 1'b0, 2'b0, 2'b0, 2'b0};
                hdr_o[31:24] <= 8'b1;
                hdr_o[39:32] <= REQUESTER_ID[15:8]; 
                hdr_o[47:40] <= REQUESTER_ID[7:0];
                hdr_o[55:48] <= cmd_tag_reg; // Tag
                hdr_o[63:56] <= {4'b0000, 4'b1111};
                hdr_o[71:64] <= cmd_reg.bus; // Bus Number
                hdr_o[79:72] <= {cmd_reg.device, cmd_reg.function_num}; // Device Number
                hdr_o[87:80] <= {4'b0000, cmd_reg.reg_num[9:6]}; // Reserved
                hdr_o[95:88] <= {cmd_reg.reg_num[5:0], 2'b00}; // Register Number (DWORD aligned)
                hdr_o[127:96] <= cmd_reg.config_data; // Write Data
            end else begin
                hdr_o[7:0] <= 8'b000_00100; // Config Read Type 0
                hdr_o[15:8]    <= {1'b0, 3'b000, 1'b0, 1'b0, 1'b0, 1'b0}; // Byte 1: R, TC[2:0]=000, R, Attr[2]=0, R, TH
                hdr_o[23:16] <= {1'b0, 1'b0, 2'b0, 2'b0, 2'b0};
                hdr_o[31:24] <= 8'b1;
                hdr_o[39:32] <= REQUESTER_ID[15:8]; 
                hdr_o[47:40] <= REQUESTER_ID[7:0];
                hdr_o[55:48] <= cmd_tag_reg; // Tag
                hdr_o[63:56] <= {4'b0000, 4'b1111};
                hdr_o[71:64] <= cmd_reg.bus; // Bus Number
                hdr_o[79:72] <= {cmd_reg.device, cmd_reg.function_num}; // Device Number
                hdr_o[87:80] <= {4'b0000, cmd_reg.reg_num[9:6]}; // Reserved
                hdr_o[95:88] <= {cmd_reg.reg_num[7:0], 2'b00}; // Register Number (DWORD aligned)
                hdr_o[127:96] <= 32'h0000_0000;
            end
        end
    end
end

always_comb begin
    if(fsm_state == FSM_SEND_HDR && hdr_ready_i) begin
        hdr_valid_o = 1'b1;
    end else begin
        hdr_valid_o = 1'b0;
    end
end

endmodule : tl_hdr_gen