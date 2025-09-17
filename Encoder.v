// 128b/130b Encoder
module encoder_128b130b (
    input  wire         clk,         // clock
    input  wire         rst_n,       // active-low reset

    input  wire [127:0] data_in,     // 128-bit input payload
    input  wire         block_type,  // 0 = data block, 1 = control block
    input  wire         valid_in,    // input data valid

    output wire [129:0] encoded_out, // 130-bit framed output
    output wire         valid_out    // output valid
);


always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic here
        encoded_out = 130'b0;
        valid_out   = 1'b0;
    end else if (valid_in)  begin
        // Encoding logic here
        if(block_type == 1'b0) begin
            // Data block encoding
            encoded_out <= {2'b01, data_in};
        end else begin
            // Control block encoding
            encoded_out <= {2'b10, data_in};
        end
    end
end




endmodule
