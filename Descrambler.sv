module pcie_descrambler_128b #(
    parameter int DW = 128
)(
    // Clocks / Reset
    input  logic              clk,
    input  logic              rst_n,

    // Scrambled payload from decoder
    input  logic [DW-1:0]     in_data,
    input  logic              in_valid,      // 1-cycle strobe
    input  logic              in_is_ctl,     // 1 = CONTROL block  (bypass)

    // Descrambled payload toward MAC / DLL
    output logic [DW-1:0]     out_data,
    output logic              out_valid      // 1-cycle strobe
);

endmodule