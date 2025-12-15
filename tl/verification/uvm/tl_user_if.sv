`ifndef TL_USER_IF_SV
`define TL_USER_IF_SV

interface tl_user_if(
  input logic clk,
  input logic rst_n
);

  import tl_pkg::*;
  
  //------------------------------------------------------------------
  // User command interface
  //------------------------------------------------------------------
  tl_cmd_t cmd;
  logic    cmd_valid;
  logic    cmd_ready;

  //------------------------------------------------------------------
  // User write data interface
  //------------------------------------------------------------------
  tl_data_t wdata;
  logic     wvalid;
  logic     wready;

  //------------------------------------------------------------------
  // User read data interface
  //------------------------------------------------------------------
  logic [63:0]            usr_read_rp_addr_o;
  logic [9:0]             usr_read_rp_length_o;
  logic [3:0]             usr_first_be_o;
  logic [3:0]             usr_last_be_o;
  logic                   usr_read_rp_valid_o;
  logic                   usr_read_rp_ready_i;

  logic [31:0]         usr_rdata_o;
  logic                usr_reop_o;
  logic                usr_rvalid_o;
  logic                usr_rready_i;         

    // Config Read Completion
  logic [7:0]             cfg_rd_tag_o;     // Tag of config read request
  logic [31:0]            cfg_rd_data_o;    // Config read data (1 DW)
  logic [2:0]             cfg_rd_status_o;  // Completion status
  logic [7:0]             cfg_rd_bus_number_o;
  logic [4:0]             cfg_rd_device_number_o;
  logic [2:0]             cfg_rd_function_number_o;
  logic                   cfg_rd_valid_o;   // Config read completion valid
  logic                   cfg_rd_ready_i;   // Config read completion ready
  
  // Config Write Completion
  logic [7:0]             cfg_wr_tag_o;     // Tag of config write request
  logic [2:0]             cfg_wr_status_o;  // Completion status
  logic [7:0]             cfg_wr_bus_number_o;
  logic [4:0]             cfg_wr_device_number_o;
  logic [2:0]             cfg_wr_function_number_o;
  logic                   cfg_wr_valid_o;   // Config write completion valid
  logic                   cfg_wr_ready_i;    // Config write completion ready


  //------------------------------------------------------------------
  // Driver Task: Send command (hardware types only)
  //------------------------------------------------------------------
  task send_command(input tl_cmd_t hw_cmd);
    
    // Wait for ready
    @(posedge clk);
    
    while (!cmd_ready) begin
      @(posedge clk);
    end
    
    
    @(posedge clk);
    cmd       <= hw_cmd;
    cmd_valid <= 1'b1;
    
    
    // Deassert valid
    @(posedge clk);
    cmd_valid <= 1'b0;
  endtask

  //------------------------------------------------------------------
  // Driver Task: Send write data beats
  //------------------------------------------------------------------
  task send_write_beats(input tl_data_t beats[$]);
    foreach (beats[i]) begin
      // Wait for ready
      while (!wready) begin
        @(posedge clk);
      end
      
      
      @(posedge clk);
      wdata  <= beats[i];
      wvalid <= 1'b1;  
    end
    
    // Deassert valid
    @(posedge clk);
    wvalid <= 1'b0;
  endtask


  //------------------------------------------------------------------
  // Utility Task: Initialize signals
  //------------------------------------------------------------------
  task init_signals();
    cmd_valid   <= 1'b0;
    cmd         <= '0;
    wdata       <= '0;
    wvalid      <= 1'b0;
    usr_rready_i <= 1'b0;
    cfg_rd_ready_i <= 1'b0;
    cfg_wr_ready_i   <= 1'b0;
  endtask

  //------------------------------------------------------------------
  // Utility Task: Wait for reset
  //------------------------------------------------------------------
  task wait_for_reset();
    @(posedge rst_n);
  endtask

endinterface :tl_user_if

`endif // TL_USER_IF_SV