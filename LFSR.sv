module lfsr #(
    parameter WIDTH = 23,                // Width of the LFSR
    parameter POLY  = 23'h0040A1B         // Feedback polynomial
)(
    input  logic         clk,        // Clock input
    input  logic         reset_n,      // Asynchronous reset
    input  logic         enable,     // Enable signal
    output logic  [WIDTH-1:0]  lfsr_out    // LFSR output
);

logic lfsr_next;


always_comb begin
    lfsr_next = ^(lfsr_out & POLY); // XOR feedback based on polynomial
end

always_ff @(posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        lfsr_out <= {WIDTH{1'b1}}; // Initialize to all ones
    end else if (enable) begin
        lfsr_out <= {lfsr_out[WIDTH-2:0], lfsr_next};
    end
end
