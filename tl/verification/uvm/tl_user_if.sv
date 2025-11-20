`ifndef TL_USER_IF_SV
`define TL_USER_IF_SV




interface tl_user_if(
  input logic clk,
  input logic rst_n
);

  import tl_pkg::*;

  // User command interface
  tl_cmd_t cmd;
  logic    cmd_valid;
  logic    cmd_ready;

  // User write data interface
  tl_data_t wdata;
  logic     wvalid;
  logic     wready;

  // User read data interface
  logic [7:0]  rtag;
  logic [63:0] raddr;
  tl_data_t    rdata;
  logic        rvalid;
  logic        rsop;
  logic        reop;
  logic        rready;

  // Memory write interface (for monitoring)
  tl_data_t memwr;
  logic     memwr_valid;
  logic     memwr_ready;

  //------------------------------------------------------------------
  // Driver Task: Send complete transaction (command + data)
  //------------------------------------------------------------------
  task send_to_dut(tl_cmd_seq_item item);
    tl_cmd_t hw_cmd;
    
    // Convert sequence item to hardware command
    hw_cmd = item.to_tl_cmd();
    
    // Step 1: Send command
    send_command(hw_cmd);
    
    // Step 2: Send data (if write)
    if (item.is_write) begin
      send_write_data(item);
    end
  endtask

  //------------------------------------------------------------------
  // Driver Task: Send command on usr_cmd_i interface
  //------------------------------------------------------------------
  task send_command(tl_cmd_t hw_cmd);
    @(posedge clk);
    cmd       <= hw_cmd;
    cmd_valid <= 1'b1;
    
    // Wait for ready
    while (!cmd_ready) begin
      @(posedge clk);
    end
    
    // Deassert valid
    @(posedge clk);
    cmd_valid <= 1'b0;
  endtask

  //------------------------------------------------------------------
  // Driver Task: Send write data on usr_wdata_i interface
  //------------------------------------------------------------------
  task send_write_data(tl_cmd_seq_item item);
    int num_beats;
    tl_data_t beat;
    
    num_beats = item.get_num_beats();
    
    for (int i = 0; i < num_beats; i++) begin
      // Prepare beat
      beat.data = item.get_data_beat(i);
      beat.sop  = (i == 0);
      beat.eop  = (i == num_beats - 1);
      beat.be   = 16'hFFFF;  // All bytes valid for simplicity
      
      // Drive beat
      @(posedge clk);
      wdata  <= beat;
      wvalid <= 1'b1;
      
      // Wait for ready
      while (!wready) begin
        @(posedge clk);
      end
    end
    
    // Deassert valid
    @(posedge clk);
    wvalid <= 1'b0;
  endtask

  //------------------------------------------------------------------
  // Monitor Task: Wait for read data (for future use)
  //------------------------------------------------------------------
  task wait_for_read_data(output tl_data_t data_out, output bit is_last);
    @(posedge clk);
    rready <= 1'b1;
    
    while (!rvalid) begin
      @(posedge clk);
    end
    
    data_out = rdata;
    is_last  = reop;
    
    @(posedge clk);
    rready <= 1'b0;
  endtask

  //------------------------------------------------------------------
  // Utility Task: Initialize signals
  //------------------------------------------------------------------
  task init_signals();
    cmd_valid  <= 1'b0;
    cmd        <= '0;
    wdata      <= '0;
    wvalid     <= 1'b0;
    rready     <= 1'b0;
    memwr_ready <= 1'b1;  // Always ready to accept memwr
  endtask

  //------------------------------------------------------------------
  // Utility Task: Wait for reset
  //------------------------------------------------------------------
  task wait_for_reset();
    @(posedge rst_n);
  endtask

endinterface : tl_user_if

`endif // TL_USER_IF_SV