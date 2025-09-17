// 128b/130b Decoder
module decoder_128b130b (
    input  wire         clk,          // clock
    input  wire         rst_n,        // active-low reset

    input  wire [129:0] encoded_in,   // 130-bit framed input
    input  wire         valid_in,     // input valid

    output wire [127:0] data_out,     // 128-bit recovered payload
    output wire         block_type,   // 0 = data block, 1 = control block
    output wire         error,        // flag if sync bits invalid
    output wire         valid_out     // output valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic here
        data_out   = 128'b0;
        block_type = 1'b0;
        error      = 1'b0;
    end else if (valid_in) begin
        // Decoding logic here
        case (encoded_in[129:128])
            2'b01: begin
                // Data block decoding
                data_out   <= encoded_in[127:0];
                block_type <= 1'b0;
                error      <= 1'b0;
            end
            2'b10: begin
                // Control block decoding
                data_out   <= encoded_in[127:0];
                block_type <= 1'b1;
                error      <= 1'b0;
            end
            default: begin
                // Invalid sync bits
                data_out   <= 128'b0;
                block_type <= 1'b0;
                error      <= 1'b1;
            end
        endcase
    end
end




endmodule
