`ifndef TL_DLL_AGENT_SV
`define TL_DLL_AGENT_SV


class tl_dll_agent extends uvm_agent;
  
  `uvm_component_utils(tl_dll_agent)
  
  // Components
  tl_dll_monitor monitor;  // Monitors tl_tx_o output
  // tl_dll_driver  driver;   // Drives tl_dll_i input (not used)
  // tl_dll_sequencer sequencer; // Sequencer (not used)   
  
  function new(string name = "tl_dll_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    // Always create monitor
    monitor = tl_dll_monitor::type_id::create("monitor", this);
  endfunction
  
endclass : tl_dll_agent

`endif // TL_DLL_AGENT_SV