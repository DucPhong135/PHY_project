module gearbox_s2p #(
    parameter OUT_W = 130
)(
    input  wire             clk, rst_n,
    input  wire             ser_bit,
    input  wire             ser_valid,
    output wire [OUT_W-1:0] dout,
    output wire             dout_valid
);
endmodule