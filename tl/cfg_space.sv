module cfg_space #(
  parameter VENDOR_ID   = 16'h1234,
  parameter DEVICE_ID   = 16'hABCD,
  parameter CLASS_CODE  = 24'h010601, // Example: bridge, PCI-to-PCI
  parameter REV_ID      = 8'h01
)(
  input  logic         clk,
  input  logic         rst_n,

  // Config TLP request interface
  input  logic         cfg_rd_en,     // 1 = config read request
  input  logic         cfg_wr_en,     // 1 = config write request
  input  logic [9:0]   cfg_addr_dw,   // DWORD offset (0–63)
  input  logic [31:0]  cfg_wdata,     // write data
  input  logic [3:0]   cfg_be,        // byte enables

  // Config TLP response
  output logic [31:0]  cfg_rdata      // read data for CplD
);

  // 256-byte config space = 64 DWORDs
  logic [31:0] cfg_regs [0:63];

  // --------------------------
  // Reset values
  // --------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // DW0: Vendor ID + Device ID
      cfg_regs[0] <= {DEVICE_ID, VENDOR_ID};

      // DW1: Command / Status
      cfg_regs[1] <= 32'h00000000;

      // DW2: Class Code / Revision ID
      cfg_regs[2] <= {CLASS_CODE, REV_ID};

      // DW3: Header Type (default 0, single function)
      cfg_regs[3] <= 32'h00000000;

      // DW4: BAR0 (example: hardcode base address)
      cfg_regs[4] <= 32'hFFFFF000; // 4KB aligned BAR

      // Rest = zeros
      for (int i = 5; i < 64; i++) begin
        cfg_regs[i] <= 32'h00000000;
      end
    end else begin
      // --------------------------
      // Write handling
      // --------------------------
      if (cfg_wr_en) begin
        // Prevent overwriting read-only registers (DW0–DW3 usually read-only)
        if (cfg_addr_dw > 3) begin
          for (int b = 0; b < 4; b++) begin
            if (cfg_be[b]) begin
              cfg_regs[cfg_addr_dw][8*b +: 8] <= cfg_wdata[8*b +: 8];
            end
          end
        end
      end
    end
  end

  // --------------------------
  // Read handling
  // --------------------------
  assign cfg_rdata = (cfg_rd_en) ? cfg_regs[cfg_addr_dw] : 32'h0;

endmodule
