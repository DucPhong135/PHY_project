`ifndef MEM_IF_SV
`define MEM_IF_SV

interface mem_if(input logic clk, input logic rst_n);
  
  import tl_pkg::*;
  
  // Write Request Channel
  memrq_t      memwr_req;
  logic        memwr_req_valid;
  logic        memwr_req_ready;
  
  // Write Data Channel
  logic [127:0] memwr_data;
  logic         memwr_data_valid;
  logic         memwr_data_ready;
  
  // Read Request Channel
  memrq_t      memrd_req;
  logic        memrd_req_valid;
  logic        memrd_req_ready;
  
  // Read Data Channel
  logic [127:0] memrd_data;
  logic         memrd_data_valid;
  logic         memrd_data_ready;
  

  task init_signals();
    memwr_req_ready = 1'b1;
    memwr_data_ready = 1'b0;
    
    memrd_req_ready = 1'b1;
    memrd_data_ready = 1'b0;
  endtask
endinterface
`endif // MEM_IF_SV