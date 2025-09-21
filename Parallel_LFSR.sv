module Parallel_LFSR #(
    parameter scramble_WIDTH = 32,
    parameter LFSR_WIDTH = 23                // Width of the LFSR
)(
    input  logic         clk,        // Clock input
    input  logic         reset_n,      // Asynchronous reset
    input  logic         enable,     // Enable signal
    input logic [scramble_WIDTH-1:0] D_IN,  // LFSR input
    output logic  [scramble_WIDTH-1:0]  D_OUT    // LFSR output
);
    logic [LFSR_WIDTH-1:0] STATE;
    logic [LFSR_WIDTH-1:0] STATE_NEXT;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n)
            STATE <= {LFSR_WIDTH{1'b1}}; // Initialize to all ones
        else if (enable)
            STATE <= STATE_NEXT;
        else 
            STATE <= STATE; // Hold state when not enabled
    end

    


// Scrambled output equations
assign D_OUT[0] = D_IN[0] ^ STATE[22];
assign D_OUT[1] = D_IN[1] ^ STATE[21];
assign D_OUT[2] = D_IN[2] ^ STATE[20];
assign D_OUT[3] = D_IN[3] ^ STATE[19];
assign D_OUT[4] = D_IN[4] ^ STATE[18];
assign D_OUT[5] = D_IN[5] ^ STATE[17];
assign D_OUT[6] = D_IN[6] ^ STATE[16];
assign D_OUT[7] = D_IN[7] ^ STATE[15];
assign D_OUT[8] = D_IN[8] ^ STATE[14];
assign D_OUT[9] = D_IN[9] ^ STATE[13];
assign D_OUT[10] = D_IN[10] ^ STATE[12];
assign D_OUT[11] = D_IN[11] ^ STATE[11];
assign D_OUT[12] = D_IN[12] ^ STATE[10];
assign D_OUT[13] = D_IN[13] ^ STATE[9];
assign D_OUT[14] = D_IN[14] ^ STATE[8];
assign D_OUT[15] = D_IN[15] ^ STATE[7];
assign D_OUT[16] = D_IN[16] ^ STATE[6];
assign D_OUT[17] = D_IN[17] ^ STATE[5];
assign D_OUT[18] = D_IN[18] ^ STATE[4];
assign D_OUT[19] = D_IN[19] ^ STATE[3];
assign D_OUT[20] = D_IN[20] ^ STATE[2];
assign D_OUT[21] = D_IN[21] ^ STATE[1];
assign D_OUT[22] = D_IN[22] ^ STATE[0];
assign D_OUT[23] = D_IN[23] ^ STATE[0] ^ STATE[2] ^ STATE[5] ^ STATE[8] ^ STATE[16] ^ STATE[21] ^ STATE[22];
assign D_OUT[24] = D_IN[24] ^ STATE[0] ^ STATE[1] ^ STATE[2] ^ STATE[4] ^ STATE[5] ^ STATE[7] ^ STATE[8] ^ STATE[15] ^ STATE[16] ^ STATE[20] ^ STATE[22];
assign D_OUT[25] = D_IN[25] ^ STATE[1] ^ STATE[2] ^ STATE[3] ^ STATE[4] ^ STATE[5] ^ STATE[6] ^ STATE[7] ^ STATE[8] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[19] ^ STATE[22];
assign D_OUT[26] = D_IN[26] ^ STATE[0] ^ STATE[1] ^ STATE[2] ^ STATE[3] ^ STATE[4] ^ STATE[5] ^ STATE[6] ^ STATE[7] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[18] ^ STATE[21];
assign D_OUT[27] = D_IN[27] ^ STATE[1] ^ STATE[3] ^ STATE[4] ^ STATE[6] ^ STATE[8] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[16] ^ STATE[17] ^ STATE[20] ^ STATE[21] ^ STATE[22];
assign D_OUT[28] = D_IN[28] ^ STATE[0] ^ STATE[2] ^ STATE[3] ^ STATE[5] ^ STATE[7] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[15] ^ STATE[16] ^ STATE[19] ^ STATE[20] ^ STATE[21];
assign D_OUT[29] = D_IN[29] ^ STATE[0] ^ STATE[1] ^ STATE[4] ^ STATE[5] ^ STATE[6] ^ STATE[8] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[18] ^ STATE[19] ^ STATE[20] ^ STATE[21] ^ STATE[22];
assign D_OUT[30] = D_IN[30] ^ STATE[2] ^ STATE[3] ^ STATE[4] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[17] ^ STATE[18] ^ STATE[19] ^ STATE[20] ^ STATE[22];
assign D_OUT[31] = D_IN[31] ^ STATE[1] ^ STATE[2] ^ STATE[3] ^ STATE[6] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[17] ^ STATE[18] ^ STATE[19] ^ STATE[21];

  // Next LFSR state after 32 bits
assign STATE_NEXT[0] = STATE[1] ^ STATE[2] ^ STATE[4] ^ STATE[6] ^ STATE[8] ^ STATE[11] ^ STATE[14] ^ STATE[15] ^ STATE[16];
assign STATE_NEXT[1] = STATE[2] ^ STATE[3] ^ STATE[5] ^ STATE[7] ^ STATE[9] ^ STATE[12] ^ STATE[15] ^ STATE[16] ^ STATE[17];
assign STATE_NEXT[2] = STATE[3] ^ STATE[4] ^ STATE[6] ^ STATE[8] ^ STATE[10] ^ STATE[13] ^ STATE[16] ^ STATE[17] ^ STATE[18];
assign STATE_NEXT[3] = STATE[4] ^ STATE[5] ^ STATE[7] ^ STATE[9] ^ STATE[11] ^ STATE[14] ^ STATE[17] ^ STATE[18] ^ STATE[19];
assign STATE_NEXT[4] = STATE[5] ^ STATE[6] ^ STATE[8] ^ STATE[10] ^ STATE[12] ^ STATE[15] ^ STATE[18] ^ STATE[19] ^ STATE[20];
assign STATE_NEXT[5] = STATE[6] ^ STATE[7] ^ STATE[9] ^ STATE[11] ^ STATE[13] ^ STATE[16] ^ STATE[19] ^ STATE[20] ^ STATE[21];
assign STATE_NEXT[6] = STATE[7] ^ STATE[8] ^ STATE[10] ^ STATE[12] ^ STATE[14] ^ STATE[17] ^ STATE[20] ^ STATE[21] ^ STATE[22];
assign STATE_NEXT[7] = STATE[0] ^ STATE[1] ^ STATE[3] ^ STATE[6] ^ STATE[8] ^ STATE[11] ^ STATE[13] ^ STATE[15] ^ STATE[17] ^ STATE[18] ^ STATE[21];    
assign STATE_NEXT[8] = STATE[1] ^ STATE[2] ^ STATE[4] ^ STATE[7] ^ STATE[9] ^ STATE[12] ^ STATE[14] ^ STATE[16] ^ STATE[18] ^ STATE[19] ^ STATE[22];    
assign STATE_NEXT[9] = STATE[0] ^ STATE[1] ^ STATE[2] ^ STATE[5] ^ STATE[6] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[13] ^ STATE[15] ^ STATE[19] ^ STATE[20] ^ STATE[22];
assign STATE_NEXT[10] = STATE[0] ^ STATE[2] ^ STATE[7] ^ STATE[10] ^ STATE[11] ^ STATE[14] ^ STATE[16] ^ STATE[17] ^ STATE[20] ^ STATE[21] ^ STATE[22]; 
assign STATE_NEXT[11] = STATE[0] ^ STATE[6] ^ STATE[8] ^ STATE[9] ^ STATE[11] ^ STATE[12] ^ STATE[15] ^ STATE[18] ^ STATE[21];
assign STATE_NEXT[12] = STATE[1] ^ STATE[7] ^ STATE[9] ^ STATE[10] ^ STATE[12] ^ STATE[13] ^ STATE[16] ^ STATE[19] ^ STATE[22];
assign STATE_NEXT[13] = STATE[0] ^ STATE[1] ^ STATE[2] ^ STATE[3] ^ STATE[6] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[13] ^ STATE[14] ^ STATE[20] ^ STATE[22];
assign STATE_NEXT[14] = STATE[0] ^ STATE[2] ^ STATE[4] ^ STATE[6] ^ STATE[7] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[14] ^ STATE[15] ^ STATE[17] ^ STATE[21] ^ STATE[22];
assign STATE_NEXT[15] = STATE[0] ^ STATE[5] ^ STATE[6] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[15] ^ STATE[16] ^ STATE[17] ^ STATE[18];
assign STATE_NEXT[16] = STATE[1] ^ STATE[6] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[16] ^ STATE[17] ^ STATE[18] ^ STATE[19];
assign STATE_NEXT[17] = STATE[2] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[17] ^ STATE[18] ^ STATE[19] ^ STATE[20];
assign STATE_NEXT[18] = STATE[3] ^ STATE[8] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[18] ^ STATE[19] ^ STATE[20] ^ STATE[21];
assign STATE_NEXT[19] = STATE[4] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[15] ^ STATE[16] ^ STATE[17] ^ STATE[19] ^ STATE[20] ^ STATE[21] ^ STATE[22];
assign STATE_NEXT[20] = STATE[0] ^ STATE[1] ^ STATE[3] ^ STATE[5] ^ STATE[6] ^ STATE[9] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[16] ^ STATE[18] ^ STATE[20] ^ STATE[21];
assign STATE_NEXT[21] = STATE[1] ^ STATE[2] ^ STATE[4] ^ STATE[6] ^ STATE[7] ^ STATE[10] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[17] ^ STATE[19] ^ STATE[21] ^ STATE[22];
assign STATE_NEXT[22] = STATE[0] ^ STATE[1] ^ STATE[2] ^ STATE[5] ^ STATE[6] ^ STATE[7] ^ STATE[8] ^ STATE[9] ^ STATE[11] ^ STATE[12] ^ STATE[13] ^ STATE[14] ^ STATE[15] ^ STATE[16] ^ STATE[17] ^ STATE[18] ^ STATE[20];

endmodule 