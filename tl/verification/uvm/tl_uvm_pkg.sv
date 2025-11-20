`ifndef TL_UVM_PKG_SV
`define TL_UVM_PKG_SV

package tl_uvm_pkg;
  
  //------------------------------------------------------------------
  // Import UVM Package
  //------------------------------------------------------------------
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  
  //------------------------------------------------------------------
  // Import Design Package
  //------------------------------------------------------------------
  import tl_pkg::*;
  
  //------------------------------------------------------------------
  // Include All UVM Components (in dependency order)
  //------------------------------------------------------------------
  
  // 1. Sequence Items (base objects)
  `include "tl_cmd_seq_item.sv"
  `include "tl_tlp_seq_item.sv"
  
  // 2. Sequences
  `include "tx_seq.sv"
  `include "tl_mem_wr_seq.sv"
  `include "tl_mem_rd_seq.sv"
  
  // 3. Driver
  `include "tl_user_driver.sv"
  
  // 4. Monitor
  `include "tl_dll_monitor.sv"
  
  // 5. Sequencers
  `include "tl_user_sequencer.sv"
  
  // 6. Agents
  `include "tl_user_agent.sv"
  `include "tl_dll_agent.sv"
  
  // 7. Scoreboard
  `include "tl_scoreboard.sv"
  
  // 8. Environment
  `include "tl_env.sv"
  
  // 9. Tests
  `include "tl_base_test.sv"
  `include "tl_tx_test.sv"

endpackage : tl_uvm_pkg

`endif // TL_UVM_PKG_SV