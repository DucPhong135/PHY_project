module tl_credit_mgr #(
  parameter int PH_WIDTH  = 12,
  parameter int PD_WIDTH  = 12,
  parameter int NPH_WIDTH = 8,
  parameter int NPD_WIDTH = 12,
  parameter int CPLH_WIDTH= 8,
  parameter int CPLD_WIDTH= 12
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // DLL credit update DLLP
  input  tl_pkg::tl_credit_t     fc_update_i,
  input  logic                   fc_valid_i,

  // Consumed credits from TX side
  input  logic                   tx_posted_i,
  input  logic                   tx_non_posted_i,

  // Status back to TX / hdr_gen
  output logic                   credit_ok_o
);

  // TODO: counters & compare

  assign credit_ok_o = 1'b1; // optimistic default

endmodule
