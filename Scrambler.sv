module pcie_scrambler_128b #(
    parameter int DW = 128    // keep DW = 128 for Gen3+ PCIe
)(
    // Clocks / Reset
    input  logic              clk,
    input  logic              rst_n,

    // Unscrambled payload from MAC / DLL
    input  logic [DW-1:0]     in_data,
    input  logic              in_valid,      // 1-cycle strobe
    input  logic              in_is_ctl,     // 1 = CONTROL block  (bypass)

    // Scrambled payload toward encoder
    output logic [DW-1:0]     out_data,
    output logic              out_valid      // 1-cycle strobe
);

endmodule