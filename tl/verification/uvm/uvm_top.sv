`ifndef UVM_TOP_SV
`define UVM_TOP_SV

`timescale 1ns/1ps

module top ();
    // Top-level UVM configuration and setup can be done 
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import tl_pkg::*;
    import tl_uvm_pkg::*;    // ✅ Single import for all UVM components

    logic clk;
    logic rst_n;
  
    // 100MHz clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Reset generation
    initial begin
        rst_n = 1;
        #10;
        rst_n = 0;
        #100;
        rst_n = 1;
    end   

  tl_user_if user_if(clk, rst_n);
  tl_dll_if  dll_if(clk, rst_n);


  tl_top #(
    .TAG_W(8),
    .DEPTH(256),
    .FIFO_DEPTH(32)
  ) dut (
    // Clock and reset
    .clk             (clk),
    .rst_n           (rst_n),
    
    // DLL interface (TLP output/input)
    .tl_tx_o         (dll_if.tl_tx_o),
    .tl_tx_valid_o   (dll_if.tl_tx_valid_o),
    .tl_tx_ready_i   (dll_if.tl_tx_ready_i),
    .tl_rx_i         (dll_if.tl_rx_i),
    .tl_rx_valid_i   (dll_if.tl_rx_valid_i),
    .tl_rx_ready_o   (dll_if.tl_rx_ready_o),
    .fc_update_i     (dll_if.fc_update_i),
    .fc_valid_i      (dll_if.fc_valid_i),
    
    // User command interface (input)
    .usr_cmd_i       (user_if.cmd),
    .usr_cmd_valid_i (user_if.cmd_valid),
    .usr_cmd_ready_o (user_if.cmd_ready),
    
    // User write data interface (input)
    .usr_wdata_i     (user_if.wdata),
    .usr_wvalid_i    (user_if.wvalid),
    .usr_wready_o    (user_if.wready),
    
    // User read data interface (output)
    .usr_rtag_o      (user_if.rtag),
    .usr_raddr_o     (user_if.raddr),
    .usr_rdata_o     (user_if.rdata),
    .usr_rvalid_o    (user_if.rvalid),
    .usr_rsop_o      (user_if.rsop),
    .usr_reop_o      (user_if.reop),
    .usr_rready_i    (user_if.rready),
    
    // Memory write interface (output - for verification)
    .memwr_o         (user_if.memwr),
    .memwr_valid_o   (user_if.memwr_valid),
    .memwr_ready_i   (user_if.memwr_ready)
  );

    initial begin
        uvm_config_db#(virtual tl_user_if)::set(null, "uvm_test_top.tx_tb.user_env.user_agent.*", "user_vif", user_if);
        uvm_config_db#(virtual tl_dll_if)::set(null, "uvm_test_top.tx_tb.dll_env.dll_agent.*", "dll_vif", dll_if);
        run_test("tl_tx_test");
    end

endmodule: top

`endif // UVM_TOP_SV
