module tl_cpl_gen #(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Command input from RX parser (triggered by MRd/ConfigRd)
  input  tl_pkg::cpl_gen_cmd_t   cpl_cmd_i,
  input  logic                   cpl_cmd_valid_i,
  output logic                   cpl_cmd_ready_o,

  // Generated Completion Header
  output logic [127:0]           cpl_hdr_o,
  output logic                   cpl_hdr_valid_o,
  input  logic                   cpl_hdr_ready_i,

  // Completion attributes
  output logic                   cpl_has_data_o,   // 1 = CplD, 0 = Cpl
  output logic [255:0]           cpl_data_o,       // completion payload
  output logic                   cpl_data_valid_o,
  input  logic                   cpl_data_ready_i
);







endmodule
