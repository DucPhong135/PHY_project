module deserializer #(
    parameter int WIDTH = 130          // width of the parallel word
)(
    // Clock / Reset
    input  wire              clk,      // same clock as the serializer
    input  wire              rst_n,    // active-LOW reset (async or sync, your choice)

    // Serial side
    input  wire              ser_in,        // serial data input, 1 bit per clk
    input  wire              ser_in_valid,  // high when ser_in carries a valid bit
                                             // (tie high if every clock has a bit)

    // Parallel side
    output wire [WIDTH-1:0]  par_out,  // re-assembled parallel word
    output wire              valid,    // 1-cycle pulse when par_out is ready

    // Status
    output wire              busy      // high while collecting bits
);

reg[WIDTH-1:0] par_reg;
reg[9:0]       bit_count;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        par_reg   <= 10'd0;
        bit_count <= 10'd0;
    end else begin
        if(ser_in_valid) begin
            par_reg <= {par_reg[WIDTH-2:0], ser_in};
            bit_count <= bit_count + 1'b1;
        end
    end
end


assign par_out = par_reg;
assign valid   = (bit_count == WIDTH) ? 1'b1 : 1'b0;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        busy <= 1'b0;
    end else begin
        if(ser_in_valid) begin
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