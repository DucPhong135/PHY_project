module tl_hdr_gen #(
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
  input  tl_pkg::tl_cmd_t        cmd_i,
  input  logic                   cmd_valid_i,
  output logic                   cmd_ready_o,

  // Allocated tag from Tag Table
  input  logic [TAG_W-1:0]       tag_i,
  input  logic                   tag_valid_i,
  output logic                   tag_consume_o,

// ---------------- Credit-manager interface ------------
  // Availability
  input  logic                   ph_credit_ok_i,
  input  logic                   pd_credit_ok_i,
  input  logic                   nph_credit_ok_i,
  input  logic                   npd_credit_ok_i,

  // Generated Header out
  output logic [127:0]           hdr_o,
  output logic                   hdr_valid_o,
  input  logic                   hdr_ready_i,

  // Header attributes
  output logic                   is_posted_o,  // 1=posted, 0=non-posted
);
  // FSM states
typedef enum logic [2:0] {
  FSM_IDLE,
  FSM_DECODE,
  FSM_WAIT_TAG,
  FSM_GEN_HDR,
  FSM_SEND_HDR,
  FSM_WAIT_CRED,
  FSM_UNSUPPORTED   // <-- new state
} fsm_e;


  logic [2:0] fsm_state, fsm_next;
  logic [TAG_W-1:0] cmd_tag_reg;
  tl_pkg::tl_cmd_t cmd_reg;

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
            if (cmd_i.type == tl_pkg::tl_cmd_type_e'('CMD_MEM) || cmd_i.type == tl_pkg::tl_cmd_type_e'('CMD_CFG)) begin
                fsm_next = FSM_WAIT_TAG;
            end else begin
                fsm_next = FSM_UNSUPPORTED; // Unsupported command type
            end
        end
        FSM_WAIT_TAG: begin
            if(cmd_reg.wr_en == 1'b1) begin
              fsm_next = FSM_GEN_HDR;
            end else if (tag_valid_i) begin
                fsm_next = FSM_GEN_HDR;
            end
        end
        FSM_GEN_HDR: begin
            case (cmd_reg.type)
                tl_pkg::tl_cmd_type_e'('CMD_MEM): begin
                    if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (ph_credit_ok_i && pd_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end 
                    else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_GEN_HDR; // wait until credits are available
                    end
                end
                tl_pkg::tl_cmd_type_e'('CMD_CFG): begin
                    if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i && npd_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end 
                    else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if( nph_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    else fsm_next = FSM_GEN_HDR; // wait until credits are available
                    end
                end
            endcase
        end
        FSM_WAIT_CRED: begin
            case (cmd_reg.type)
                tl_pkg::tl_cmd_type_e'('CMD_MEM): begin
                    if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (ph_credit_ok_i && pd_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_WAIT_CRED; // wait until credits are available
                    end
                end
                tl_pkg::tl_cmd_type_e'('CMD_CFG): begin
                    if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i && npd_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if(nph_credit_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_WAIT_CRED; // wait until credits are available
                    end
                end
                default: begin
                    fsm_next = FSM_UNSUPPORTED; // Unsupported command type
                end
            endcase
        end
        FSM_SEND_HDR: begin
            case (cmd_reg.type)
                tl_pkg::tl_cmd_type_e'('CMD_MEM): begin
                    if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (ph_credit_ok_i && pd_credit_ok_i) begin
                            fsm_next = FSM_IDLE; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i) begin
                            fsm_next = FSM_IDLE; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_SEND_HDR; 
                    end
                end
                tl_pkg::tl_cmd_type_e'('CMD_CFG): begin
                   if(cmd_reg.wr_en && hdr_ready_i) begin
                        if (nph_credit_ok_i && npd_credit_ok_i) begin
                            fsm_next = FSM_IDLE; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else if(!cmd_reg.wr_en && hdr_ready_i) begin
                        if( nph_credit_ok_i) begin
                            fsm_next = FSM_IDLE; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_SEND_HDR; 
                    end
                end
                default: begin
                    fsm_next = FSM_UNSUPPORTED; // Unsupported command type
                end
            endcase
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
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // reset logic
        cmd_ready_o   <= 1'b0;
    end else begin
        if(fsm_state == FSM_IDLE) begin
            cmd_ready_o <= 1'b1;
        end else begin
            cmd_ready_o <= 1'b0;
        end
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


always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tag_consume_o <= 1'b0;
    end else begin
        if (fsm_state == FSM_WAIT_TAG && tag_valid_i) begin
            tag_consume_o <= 1'b1;
        end else begin
            tag_consume_o <= 1'b0;
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
        if(cmd_reg.type == tl_pkg::tl_cmd_type_e'('CMD_MEM)) begin
            if(cmd_reg.addr[63:32] != 32'h0) begin
                // 64-bit address
                if(cmd_reg.wr_en == 1'b1) begin
                    hdr_o[127:120] <= 8'h60; // Memory Write 64
                    hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                    hdr_o[111] <= 1'b1; //TD bit
                    hdr_o[110] <= 1'b0; //EP bit
                    hdr_o[109:106] <= 4'b0000; //Attr + AT
                    hdr_o[105:96] <= cmd_reg.len; // Length in DWs
                    hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                    hdr_o[79:72] <= 8'h00; // Tag
                    // Byte Enables
                    case (cmd_reg.addr[1:0]) // DW alignment
                        2'b00: begin
                            hdr_o[67:64] <= 4'b1111; // First DW BE
                            hdr_o[71:68] <= 4'b1111; // Last DW BE
                        end
                        2'b01: begin
                            hdr_o[67:64] <= 4'b1110;
                            hdr_o[71:68] <= 4'b0001;
                        end
                        2'b10: begin
                            hdr_o[67:64] <= 4'b1100;
                            hdr_o[71:68] <= 4'b0011;
                        end
                        2'b11: begin
                            hdr_o[67:64] <= 4'b1000;
                            hdr_o[71:68] <= 4'b0111;
                        end
                        default: begin 
                            hdr_o[67:64] <= 4'b1111;
                            hdr_o[71:68] <= 4'b1111;
                        end
                    endcase
                    hdr_o[63:32] <= cmd_reg.addr[63:32]; // Address [63:32]
                    hdr_o[31:2] <= cmd_reg.addr[31:2]; // Address [31:2]
                    hdr_o[1:0] <= 2'b00; // Reserved
                end else begin
                    hdr_o[127:120] <= 8'h20; // Memory Read 64
                    hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                    hdr_o[111] <= 1'b1; //TD bit
                    hdr_o[110] <= 1'b0; //EP bit
                    hdr_o[109:106] <= 4'b0000; //Attr + AT
                    hdr_o[105:96] <= cmd_reg.len; // Length in DWs
                    hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                    hdr_o[79:72] <= cmd_tag_reg; // Tag
                    // Byte Enables
                    case (cmd_reg.addr[1:0]) // DW alignment
                        2'b00: begin
                            hdr_o[67:64] <= 4'b1111; // First DW BE
                            hdr_o[71:68] <= 4'b1111; // Last DW BE
                        end
                        2'b01: begin
                            hdr_o[67:64] <= 4'b1110;
                            hdr_o[71:68] <= 4'b0001;
                        end
                        2'b10: begin
                            hdr_o[67:64] <= 4'b1100;
                            hdr_o[71:68] <= 4'b0011;
                        end
                        2'b11: begin
                            hdr_o[67:64] <= 4'b1000;
                            hdr_o[71:68] <= 4'b0111;
                        end
                        default: begin 
                            hdr_o[67:64] <= 4'b1111;
                            hdr_o[71:68] <= 4'b1111;
                        end
                    endcase
                    hdr_o[63:32] <= cmd_reg.addr[63:32]; // Address [63:32]
                    hdr_o[31:2] <= cmd_reg.addr[31:2]; // Address [31:2]
                    hdr_o[1:0] <= 2'b00; // Reserved
                end
            end else begin
                // 32-bit address
                if(cmd_reg.wr_en == 1'b1) begin
                    hdr_o[127:120] <= 8'h40; // Memory Write 32
                    hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                    hdr_o[111] <= 1'b1; //TD bit
                    hdr_o[110] <= 1'b0; //EP bit
                    hdr_o[109:106] <= 4'b0000; //Attr + AT
                    hdr_o[105:96] <= cmd_reg.len; // Length in DWs
                    hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                    hdr_o[79:72] <= 8'h00; // Tag
                    // Byte Enables
                    case (cmd_reg.addr[1:0]) // DW alignment
                        2'b00: begin
                            hdr_o[67:64] <= 4'b1111; // First DW BE
                            hdr_o[71:68] <= 4'b1111; // Last DW BE
                        end
                        2'b01: begin
                            hdr_o[67:64] <= 4'b1110;
                            hdr_o[71:68] <= 4'b0001;
                        end
                        2'b10: begin
                            hdr_o[67:64] <= 4'b1100;
                            hdr_o[71:68] <= 4'b0011;
                        end
                        2'b11: begin
                            hdr_o[67:64] <= 4'b1000;
                            hdr_o[71:68] <= 4'b0111;
                        end
                        default: begin 
                            hdr_o[67:64] <= 4'b1111;
                            hdr_o[71:68] <= 4'b1111;
                        end
                    endcase
                    hdr_o[63:34] <= cmd_reg.addr[31:2]; // Address [63:32]
                    hdr_o[33:32] <= 2'b00; // Reserved
                    hdr_o[31:0] <= 32'hXXXX_XXXX; // No Address [31:0] for 32-bit addr
                end else begin
                    hdr_o[127:120] <= 8'h00; // Memory Read 32
                    hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                    hdr_o[111] <= 1'b1; //TD bit
                    hdr_o[110] <= 1'b0; //EP bit
                    hdr_o[109:106] <= 4'b0000; //Attr + AT
                    hdr_o[105:96] <= cmd_reg.len; // Length in DWs
                    hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                    hdr_o[79:72] <= cmd_tag_reg; // Tag
                    // Byte Enables
                    case (cmd_reg.addr[1:0]) // DW alignment
                        2'b00: begin
                            hdr_o[67:64] <= 4'b1111; // First DW BE
                            hdr_o[71:68] <= 4'b1111; // Last DW BE
                        end
                        2'b01: begin
                            hdr_o[67:64] <= 4'b1110;
                            hdr_o[71:68] <= 4'b0001;
                        end
                        2'b10: begin
                            hdr_o[67:64] <= 4'b1100;
                            hdr_o[71:68] <= 4'b0011;
                        end
                        2'b11: begin
                            hdr_o[67:64] <= 4'b1000;
                            hdr_o[71:68] <= 4'b0111;
                        end
                        default: begin 
                            hdr_o[67:64] <= 4'b1111;
                            hdr_o[71:68] <= 4'b1111;
                        end
                    endcase
                    hdr_o[63:34] <= cmd_reg.addr[31:2]; // Address [63:32]
                    hdr_o[33:32] <= 2'b00; // Reserved
                    hdr_o[31:0] <= 32'h0000_0000; // No Address [31:0] for 32-bit addr
                end
            end
        end
        else if(cmd_reg.type == tl_pkg::tl_cmd_type_e'('CMD_CFG)) begin
            if(cmd_reg.wr_en == 1'b1) begin
                hdr_o[127:120] <= 8'h44; // Config Write Type 0
                hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                hdr_o[111] <= 1'b1; //TD bit
                hdr_o[109] <= 1'b0; //EP bit
                hdr_o[109:106] <= 4'b0000; //Attr + AT
                hdr_o[105:96] <= 10'b1; // Length in DWs
                hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                hdr_o[79:72] <= cmd_tag_reg; // Tag
                hdr_o[71:68] <= 4'b0000; // Byte Enables last
                hdr_o[67:64] <= 4'b1111; // Byte Enables first (set default)
                hdr_o[63:56] <= cmd_reg.bus; // Bus Number
                hdr_o[55:51] <= cmd_reg.device; // Device Number
                hdr_o[50:48] <= cmd_reg.function_num; // Function Number
                hdr_o[47:44] <= 4'b0000; // Reserved
                hdr_o[43:32] <= {cmd_reg.reg_num, 2'b00}; // Register Number (DWORD aligned)
                hdr_o[31:0] <= 32'h0000_0000; // No Address [31:0] for Config
            end else begin
                hdr_o[127:120] <= 8'h04; // Config Read Type 0
                hdr_o[119:112] <= 4'b0000; // TC=0, Reserved=0
                hdr_o[111] <= 1'b1; //TD bit
                hdr_o[109] <= 1'b0; //EP bit
                hdr_o[109:106] <= 4'b0000; //Attr + AT
                hdr_o[105:96] <= 10'b1; // Length in DWs
                hdr_o[95:80] <= REQUESTER_ID; // Requester ID
                hdr_o[79:72] <= cmd_tag_reg; // Tag
                hdr_o[71:68] <= 4'b0000; // Byte Enables last
                hdr_o[67:64] <= 4'b1111; // Byte Enables first (set to all 1s for read)
                hdr_o[63:56] <= cmd_reg.bus; // Bus Number
                hdr_o[55:51] <= cmd_reg.device; // Device Number
                hdr_o[50:48] <= cmd_reg.function_num; // Function Number
                hdr_o[47:44] <= 4'b0000; // Reserved
                hdr_o[43:32] <= {cmd_reg.reg_num, 2'b00}; // Register Number (DWORD aligned)
                hdr_o[31:0] <= 32'h0000_0000; // No Address [31:0] for Config
            end
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        hdr_valid_o <= 1'b0;
    end else begin
        if(hdr_valid_o == 1'b1) 
            hdr_valid_o <= 1'b0; // de-assert after one cycle
        else if (fsm_state == FSM_SEND_HDR) begin
            if(cmd_reg.wr_en == 1'b1 && hdr_ready_i && ph_credit_ok_i && pd_credit_ok_i) begin
                hdr_valid_o <= 1'b1; // For write, go back to IDLE after sending header
            end else if(!cmd_reg.wr_en && hdr_ready_i && nph_credit_ok_i) begin
                hdr_valid_o <= 1'b1; // For read, go back to IDLE after sending header
            end else begin
                hdr_valid_o <= 1'b0;
            end
        end
    end
end

assign is_posted_o = (cmd_reg.type == tl_pkg::tl_cmd_type_e'('CMD_MEM) && cmd_reg.wr_en) ? 1'b1 : 1'b0;
endmodule
