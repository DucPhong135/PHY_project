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
  logic [7:0]  rtag;
  logic [63:0] raddr;
  tl_data_t    rdata;
  logic        rvalid;
  logic        rsop;
  logic        reop;
  logic        rready;

  //------------------------------------------------------------------
  // Memory write interface (for monitoring)
  //------------------------------------------------------------------
  tl_data_t memwr;
  logic     memwr_valid;
  logic     memwr_ready;

  //------------------------------------------------------------------
  // Driver Task: Send command (hardware types only)
  //------------------------------------------------------------------
  task send_command(input tl_cmd_t hw_cmd);
    
    // Wait for ready
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
  // Monitor Task: Wait for read data
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
    cmd_valid   <= 1'b0;
    cmd         <= '0;
    wdata       <= '0;
    wvalid      <= 1'b0;
    rready      <= 1'b0;
    memwr_ready <= 1'b1;
  endtask

  //------------------------------------------------------------------
  // Utility Task: Wait for reset
  //------------------------------------------------------------------
  task wait_for_reset();
    @(posedge rst_n);
  endtask

endinterface :tl_user_if

`endif // TL_USER_IF_SV