module gearbox_p2s #(
    parameter IN_W  = 130
)(
    input  wire             clk, rst_n,
    input  wire [IN_W-1:0]  din,
    input  wire             din_valid,
    output wire             din_ready,
    output wire             ser_bit,
    output wire             ser_valid,
    output wire             busy
);
endmodule