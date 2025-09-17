module scrambler_128b (
    input  wire         clk, rst_n,
    input  wire [129:0] in_130,     // [129:128]=header, [127:0]=payload
    input  wire         valid_in,
    output wire [129:0] out_130,    // payload scrambled, header passthrough
    output wire         valid_out
);
endmodule