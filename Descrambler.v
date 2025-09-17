module descrambler_128b (
    input  wire         clk, rst_n,
    input  wire [129:0] in_130,
    input  wire         valid_in,
    output wire [129:0] out_130,
    output wire         valid_out,
    output wire [31:0]  err_count   // optional correlation/errors
);
endmodule