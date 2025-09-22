module tl_payload_mux #(
  parameter int STREAM_W = 128
)(
  input  logic                     clk,
  input  logic                     rst_n,

  // Upstream write-data from user
  input  tl_pkg::tl_data_t         wdata_i,
  input  logic                     wdata_valid_i,
  output logic                     wdata_ready_o,

  // Header arrival from hdr_gen (needed for alignment)
  input  logic                     hdr_valid_i,
  input  logic                     hdr_ready_o,

  // Combined header+payload stream to TX arbiter
  output tl_pkg::tl_stream_t       tx_pkt_o,
  output logic                     tx_pkt_valid_o,
  input  logic                     tx_pkt_ready_i
);

  // TODO: implement gather / align

  assign wdata_ready_o   = 1'b0;
  assign tx_pkt_o        = '0;
  assign tx_pkt_valid_o  = 1'b0;

endmodule
