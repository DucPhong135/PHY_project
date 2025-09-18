// 128b/130b Decoder
module pcie_128b130b_decoder (
    input  logic             clk,
    input  logic             rst_n,

    // Encoded 130-bit block in
    input  logic [129:0]     in_block,
    input  logic             in_valid,     // 1-cycle strobe

    // Decoded 128-bit payload out
    output logic [127:0]     out_data,
    output logic             out_valid,    // 1-cycle strobe
    output logic             out_is_ctl,   // 1 = CONTROL block (unscrambled)
    output logic             header_err    // 1 = illegal SH (00 or 11)
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic here
        out_data   = 128'b0;
        out_is_ctl = 1'b0;
        header_err = 1'b0;
    end else if (in_valid) begin
        // Decoding logic here
        case (in_block[129:128])
            2'b01: begin
                // Data block decoding
                out_data   <= in_block[127:0];
                out_is_ctl <= 1'b0;
                header_err      <= 1'b0;
            end
            2'b10: begin
                // Control block decoding
                out_data   <= in_block[127:0];
                out_is_ctl <= 1'b1;
                header_err      <= 1'b0;
            end
            default: begin
                // Invalid sync bits
                out_data   <= 128'b0;
                out_is_ctl <= 1'b0;
                header_err      <= 1'b1;
            end
        endcase
    end
end




endmodule
