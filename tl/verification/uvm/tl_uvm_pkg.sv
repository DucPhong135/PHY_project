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
  `include "tl_user_seq_item.sv"
  `include "tl_tlp_seq_item.sv"
  `include "mem_seq_item.sv"
  
  // 2. Sequences
  `include "tx_mem_read_seq.sv"
  `include "tx_mem_write_seq.sv"
  `include "tx_cfg_read_seq.sv"
  `include "tx_cfg_write_seq.sv"
  `include "tx_seq.sv"

  `include "rx_memory_seq.sv"
  `include "rx_seq.sv"
  
  // 3. Driver
  `include "tl_user_driver.sv"
  `include "tl_dll_driver.sv"
  
  // 4. Monitor
  `include "tl_user_monitor.sv"
  `include "tl_dll_monitor.sv"
  `include "mem_monitor.sv"
  
  // 5. Sequencers
  `include "tl_user_sequencer.sv"
  `include "tl_dll_sequencer.sv"

  // memory_model.sv

  `include "mem_storage.sv"
  `include "tl_memory_model.sv"
  
  // 6. Agents
  `include "tl_user_agent.sv"
  `include "tl_dll_agent.sv"
  `include "mem_agent.sv"
  
//  // 7. Scoreboard
  `include "tx_scoreboard.sv"
  `include "rx_scoreboard.sv"

  // 8. Environment
  `include "tl_user_env.sv"
  `include "tl_dll_env.sv"
  `include "mem_env.sv"

  `include "tl_tb.sv"
  
  // 9. Tests
  `include "tl_tx_test.sv"
  `include "tl_rx_test.sv"

endpackage : tl_uvm_pkg

`endif // TL_UVM_PKG_SV