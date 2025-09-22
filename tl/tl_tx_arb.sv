module tl_tx_arb #(
  parameter int STREAM_W = 128
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Posted queue
  input  tl_pkg::tl_stream_t     pkt_posted_i,
  input  logic                   pkt_posted_valid_i,
  output logic                   pkt_posted_ready_o,

  // Non-posted queue
  input  tl_pkg::tl_stream_t     pkt_np_i,
  input  logic                   pkt_np_valid_i,
  output logic                   pkt_np_ready_o,

  // Arbitrated output to DLL
  output tl_pkg::tl_stream_t     tl_tx_o,
  output logic                   tl_tx_valid_o,
  input  logic                   tl_tx_ready_i
);

  // TODO: round-robin or priority

  assign pkt_posted_ready_o = 1'b0;
  assign pkt_np_ready_o     = 1'b0;
  assign tl_tx_o            = '0;
  assign tl_tx_valid_o      = 1'b0;

endmodule
