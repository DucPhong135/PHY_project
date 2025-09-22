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

  // TODO: implement header generation FSM

  // place-holders
  assign cmd_ready_o    = 1'b0;
  assign tag_consume_o  = 1'b0;
  assign hdr_o          = '0;
  assign hdr_valid_o    = 1'b0;
  assign is_posted_o    = 1'b0;
  assign is_cpl_o       = 1'b0;

endmodule
