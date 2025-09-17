module serializer #(
    parameter WIDTH = 130
)(
    input  wire             clk, rst_n,
    input  wire [WIDTH-1:0] par_in,
    input  wire             load,
    output wire             ser_out,
    output wire             busy
);
endmodule