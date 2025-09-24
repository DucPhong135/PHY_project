module cfg_space #(
  //--------------------------------------------------------------------
  // Identification parameters (static for the life-time of the device)
  //--------------------------------------------------------------------
  parameter VENDOR_ID   = 16'h1234,
  parameter DEVICE_ID   = 16'hABCD,
  parameter CLASS_CODE  = 24'h010601,   // example: bridge, PCI-to-PCI
  parameter REV_ID      = 8'h01,

  //--------------------------------------------------------------------
  // BDF of *this* function (hard-wired in most endpoints)
  //--------------------------------------------------------------------
  parameter logic [4:0] DEV_NUM  = 5'd0,
  parameter logic [2:0] FUNC_NUM = 3'd0
)(
  input  logic         clk,
  input  logic         rst_n,

  // Config-space TLP request interface
  input  logic         cfg_rd_en,
  input  logic         cfg_wr_en,
  input  logic [9:0]   cfg_addr_dw,   // DWORD offset (0-63)
  input  logic [31:0]  cfg_wdata,
  input  logic [3:0]   cfg_be,

  // -------------------------------------------------------------------
  // Exported Requester / Completer ID (used by hdr_gen & cpl_gen)
  // -------------------------------------------------------------------
  output logic [15:0]  requester_id_o,

  // Config-space read data (for Completion with Data)
  output logic [31:0]  cfg_rdata
);

  // ----------------------------------------------------------
  // Internal configuration-space image (256 B = 64 DWORDs)
  // ----------------------------------------------------------
  logic [31:0] cfg_regs [0:63];

  // Register that holds Primary-Bus Number (captured from DW6)
  logic [7:0]  bus_num_r;

  // ----------------------------------------------------------
  // Reset values
  // ----------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // DW0: Vendor | Device
      cfg_regs[0] <= {DEVICE_ID, VENDOR_ID};

      // DW1: Command / Status
      cfg_regs[1] <= 32'h0000_0000;

      // DW2: Class Code | Revision ID
      cfg_regs[2] <= {CLASS_CODE, REV_ID};

      // DW3: Header Type, BIST, etc.
      cfg_regs[3] <= 32'h0000_0000;

      // DW4-DW5: BAR0..BAR1 (example)
      cfg_regs[4] <= 32'hFFFF_F000;   // BAR0 size mask
      cfg_regs[5] <= 32'h0000_0000;   // BAR1

      // DW6: Primary / Secondary / Subordinate Bus #
      cfg_regs[6] <= 32'h0000_0000;   // will be programmed by RC
      bus_num_r   <= 8'd0;

      // Rest to zeros
      for (int i = 7; i < 64; i++)
        cfg_regs[i] <= '0;
    end
    // --------------------------------------------------------
    // Write handling
    // --------------------------------------------------------
    else if (cfg_wr_en) begin
      // Allow all BARs & capability registers to be updated
      // Block writes to read-only IDs (DW0-DW2) if needed
      if (cfg_addr_dw > 2) begin
        // Byte-enable granularity
        for (int b = 0; b < 4; b++) begin
          if (cfg_be[b])
            cfg_regs[cfg_addr_dw][8*b +: 8] <= cfg_wdata[8*b +: 8];
        end
      end

      // Special handling for DW6 → capture Primary-Bus #
      if (cfg_addr_dw == 10'd6) begin
        bus_num_r <= cfg_wdata[23:16];          // Primary Bus Number
      end
    end
  end

  // ----------------------------------------------------------
  // Read-back path
  // ----------------------------------------------------------
  assign cfg_rdata = (cfg_rd_en) ? cfg_regs[cfg_addr_dw] : 32'h0;

  // ----------------------------------------------------------
  // Concatenate the live BDF into a 16-bit Requester ID
  // ----------------------------------------------------------
  assign requester_id_o = { bus_num_r, DEV_NUM, FUNC_NUM };
endmodule
