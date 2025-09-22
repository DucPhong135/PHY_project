module tl_tag_table #(
  parameter int TAG_W   = 8,
  parameter int DEPTH   = 1<<8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Allocate request (from hdr_gen for MemRd/CfgRd)
  input  logic                   alloc_req_i,
  output logic [TAG_W-1:0]       alloc_tag_o,
  output logic                   alloc_gnt_o,

  // Free tag (from completion engine)
  input  logic [TAG_W-1:0]       free_tag_i,
  input  logic                   free_valid_i
);

  // TODO: free-list or simple counter

  assign alloc_tag_o = '0;
  assign alloc_gnt_o = 1'b0;

endmodule
