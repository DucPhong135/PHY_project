`ifndef UVM_TOP_SV
`define UVM_TOP_SV

`timescale 1ns/1ps

module top ();
    `include "uvm_macros.svh"
    import uvm_pkg::*;
    import tl_pkg::*;
    import tl_uvm_pkg::*;

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
  mem_if   mem_if(clk, rst_n);


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
    .usr_read_rp_addr_o (user_if.usr_read_rp_addr_o),
    .usr_read_rp_length_o (user_if.usr_read_rp_length_o),
    .usr_first_be_o    (user_if.usr_first_be_o),
    .usr_last_be_o     (user_if.usr_last_be_o),
    .usr_read_rp_valid_o (user_if.usr_read_rp_valid_o),
    .usr_read_rp_ready_i (user_if.usr_read_rp_ready_i),

    .usr_rdata_o      (user_if.usr_rdata_o),
    .usr_reop_o       (user_if.usr_reop_o),
    .usr_rvalid_o     (user_if.usr_rvalid_o),
    .usr_rready_i     (user_if.usr_rready_i),

    .cfg_rd_tag_o   (user_if.cfg_rd_tag_o), 
    .cfg_rd_data_o  (user_if.cfg_rd_data_o),    
    .cfg_rd_status_o(user_if.cfg_rd_status_o),
    .cfg_rd_bus_number_o     (user_if.cfg_rd_bus_number_o),
    .cfg_rd_device_number_o  (user_if.cfg_rd_device_number_o),
    .cfg_rd_function_number_o(user_if.cfg_rd_function_number_o),
    .cfg_rd_valid_o (user_if.cfg_rd_valid_o),   
    .cfg_rd_ready_i (user_if.cfg_rd_ready_i),  

    .cfg_wr_tag_o   (user_if.cfg_wr_tag_o),
    .cfg_wr_status_o(user_if.cfg_wr_status_o),
    .cfg_wr_bus_number_o     (user_if.cfg_wr_bus_number_o),
    .cfg_wr_device_number_o  (user_if.cfg_wr_device_number_o),
    .cfg_wr_function_number_o(user_if.cfg_wr_function_number_o),
    .cfg_wr_valid_o (user_if.cfg_wr_valid_o),   
    .cfg_wr_ready_i (user_if.cfg_wr_ready_i),   
    
    // Memory Write Request Channel
    .memwr_req_o       (mem_if.memwr_req),
    .memwr_req_valid_o (mem_if.memwr_req_valid),
    .memwr_req_ready_i (mem_if.memwr_req_ready),
    
    // Memory Write Data Channel
    .memwr_data_o       (mem_if.memwr_data),
    .memwr_data_valid_o (mem_if.memwr_data_valid),
    .memwr_data_ready_i (mem_if.memwr_data_ready),
    
    // Memory Read Request Channel
    .memrd_req_o       (mem_if.memrd_req),
    .memrd_req_valid_o (mem_if.memrd_req_valid),
    .memrd_req_ready_i (mem_if.memrd_req_ready),
    
    // Memory Read Data Channel
    .memrd_data_i       (mem_if.memrd_data),
    .memrd_data_valid_i (mem_if.memrd_data_valid),
    .memrd_data_ready_o (mem_if.memrd_data_ready)
  );

    initial begin
        uvm_config_db#(virtual tl_user_if)::set(null, "uvm_test_top.tx_tb.user_env.user_agent.*", "user_vif", user_if);
        uvm_config_db#(virtual tl_dll_if)::set(null, "uvm_test_top.tx_tb.dll_env.dll_agent.*", "dll_vif", dll_if);
        uvm_config_db#(virtual mem_if)::set(null, "uvm_test_top.tx_tb.memory_env.*", "mem_vif", mem_if);


        uvm_config_db#(virtual tl_user_if)::set(null, "uvm_test_top.rx_tb.user_env.user_agent.*", "user_vif", user_if);
        uvm_config_db#(virtual tl_dll_if)::set(null, "uvm_test_top.rx_tb.dll_env.dll_agent.*", "dll_vif", dll_if);
        uvm_config_db#(virtual mem_if)::set(null, "uvm_test_top.rx_tb.memory_env.agent.*", "mem_vif", mem_if);
        uvm_config_db#(virtual mem_if)::set(null, "uvm_test_top.rx_tb.memory_env.*", "mem_vif", mem_if);

        uvm_config_db#(virtual tl_user_if)::set(null, "uvm_test_top.cpl_tb.user_env.user_agent.*", "user_vif", user_if);
        uvm_config_db#(virtual tl_dll_if)::set(null, "uvm_test_top.cpl_tb.dll_env.dll_agent.*", "dll_vif", dll_if);
        uvm_config_db#(virtual mem_if)::set(null, "uvm_test_top.cpl_tb.memory_env.agent.*", "mem_vif", mem_if);
        uvm_config_db#(virtual mem_if)::set(null, "uvm_test_top.cpl_tb.memory_env.*", "mem_vif", mem_if);

        // run_test("tl_rx_test");
        //run_test("tl_cpl_test");
        run_test("tl_tx_test");
    end

endmodule: top

`endif // UVM_TOP_SV