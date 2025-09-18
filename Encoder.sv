// 128b/130b Encoder
module pcie_128b130b_encoder (
    input  logic             clk,
    input  logic             rst_n,

    // Parallel 128-bit word in
    input  logic [127:0]     in_data,
    input  logic             in_valid,   // 1-cycle strobe
    input  logic             in_is_ctl,  // 1 = CONTROL block (unscrambled)

    // Encoded 130-bit block out
    output logic [129:0]     out_block,
    output logic             out_valid
);



always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset logic here
        out_block = 130'b0;
        out_valid = 1'b0;
    end else if (in_valid)  begin
        // Encoding logic here
        if(in_is_ctl == 1'b0) begin
            // Data block encoding
            encoded_out <= {2'b01, data_in};
        end else begin
            // Control block encoding
            encoded_out <= {2'b10, data_in};
        end
    end
end




endmodule
