module tl_rx_parser #(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Stream from DLL
  input  tl_pkg::tl_stream_t     tl_rx_i,
  input  logic                   tl_rx_valid_i,
  output logic                   tl_rx_ready_o,

  // Memory Write to user
  output tl_pkg::tl_data_t       memwr_o,
  output logic                   memwr_valid_o,
  input  logic                   memwr_ready_i,

  // Completion to Completion Engine
  output logic [TAG_W-1:0]       cpl_tag_o,
  output tl_pkg::tl_data_t       cpl_data_o,
  output logic                   cpl_valid_o,
  input  logic                   cpl_ready_i
);

  // TODO: header decode, ECRC, etc.

  assign tl_rx_ready_o   = 1'b0;
  assign memwr_o         = '0;
  assign memwr_valid_o   = 1'b0;
  assign cpl_tag_o       = '0;
  assign cpl_data_o      = '0;
  assign cpl_valid_o     = 1'b0;

endmodule
