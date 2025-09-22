module tl_hdr_gen #(
  parameter int TAG_W             = 8,
  parameter int MAX_PAYLOAD_BYTES = 256
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // User command channel
  input  tl_pkg::tl_cmd_t        cmd_i,
  input  logic                   cmd_valid_i,
  output logic                   cmd_ready_o,

  // Allocated tag from Tag Table
  input  logic [TAG_W-1:0]       tag_i,
  input  logic                   tag_valid_i,
  output logic                   tag_consume_o,

  // Credit status from Credit Manager
  input  logic                   credit_ok_i,

  // Generated Header out
  output logic [127:0]           hdr_o,
  output logic                   hdr_valid_o,
  input  logic                   hdr_ready_i,

  // Header attributes
  output logic                   is_posted_o,  // 1=posted, 0=non-posted
  output logic                   is_cpl_o      // for replay buffer, etc.
);
  // FSM states
  localparam FSM_IDLE      = 2'b00;
  localparam FSM_WAIT_TAG  = 2'b01;
  localparam FSM_GEN_HDR   = 2'b10;
  localparam FSM_WAIT_CRED = 2'b11;

  logic [1:0] fsm_state, fsm_next;
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
                fsm_next = FSM_WAIT_TAG;
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
            if (hdr_ready_i) begin
                if (credit_ok_i) begin
                    fsm_next = FSM_IDLE;
                end else begin
                    fsm_next = FSM_WAIT_CRED;
                end
            end
        end
        FSM_WAIT_CRED: begin
            if (credit_ok_i && hdr_ready_i) begin
                fsm_next = FSM_IDLE;
            end
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


always_comb begin
    if(cmd_reg.type == tl_pkg::tl_cmd_type_e'('CMD_MEM)) begin
        hdr_o[7:0]    = (cmd_reg.wr_en) ? 8'h20 : 8'h00; // Fmt/Type: 32-bit Memory Read/Write
        hdr_o[15:8]   = 8'h00; // TC/Reserved
        hdr_o[]


assign is_posted_o = (cmd_reg.type == tl_pkg::tl_cmd_type_e'('CMD_MEM) && cmd_reg.wr_en) ? 1'b1 : 1'b0;
assign is_cpl_o    = (cmd_reg.type != tl_pkg::tl_cmd_type_e'('CMD_MEM) || !cmd_reg.wr_en) ? 1'b1 : 1'b0;
endmodule
