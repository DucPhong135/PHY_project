module tl_cpl_engine #(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Completion from RX parser
  input  logic [TAG_W-1:0]       cpl_tag_i,
  input  tl_pkg::tl_data_t       cpl_data_i,
  input  logic                   cpl_valid_i,
  output logic                   cpl_ready_o,

  // Outstanding Request Table access
  output logic [TAG_W-1:0]       ort_rd_tag_o,
  output logic                   ort_rd_en_o,

  // Returned data to user
  output tl_pkg::tl_data_t       usr_rdata_o,
  output logic                   usr_rvalid_o,
  input  logic                   usr_rready_i
);

  // TODO: match tag, drive user read data

  assign cpl_ready_o    = 1'b0;
  assign ort_rd_tag_o   = '0;
  assign ort_rd_en_o    = 1'b0;
  assign usr_rdata_o    = '0;
  assign usr_rvalid_o   = 1'b0;

endmodule
