module serializer #(
    parameter WIDTH = 130
)(
    input  wire             clk, rst_n,
    input  wire [WIDTH-1:0] par_in,
    input  wire             load,
    output wire             ser_out,
    output wire             busy
);

reg [WIDTH-1:0] shift_reg;
reg [9:0]       bit_count;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        ser_out <= 1'b0;
    end else begin
        if(load) begin
            shift_reg <= par_in;
            bit_count <= 10'd0;
            ser_out   <= par_in[WIDTH-1];
        end else if(busy) begin
            shift_reg <= {shift_reg[WIDTH-2:0], 1'b0};
            bit_count <= bit_count + 1'b1;
        end else begin
            shift_reg <= 10'd0;
            bit_count <= 10'd0;
        end
    end
end

assign ser_out = shift_reg[WIDTH-1];


always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        busy <= 1'b0;
    end else begin
        if(load) begin
            busy <= 1'b1;
        end else if(bit_count == WIDTH) begin
            busy <= 1'b0;
        end
        else begin
            busy <= busy;
        end
    end
end



endmodule