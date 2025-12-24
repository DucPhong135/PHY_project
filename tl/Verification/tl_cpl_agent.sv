`ifndef TL_DLL_AGENT_SV
`define TL_DLL_AGENT_SV


class tl_cpl_agent extends uvm_agent;
  
  `uvm_component_utils(tl_dll_agent)

  bit monitor_cpl = 1'b0;
  
  tl_dll_monitor dll_monitor;  
  tl_dll_driver  dll_driver;  
  tl_dll_sequencer dll_sequencer;   
  
  function new(string name = "tl_dll_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(is_active == UVM_ACTIVE) begin
      dll_driver = tl_dll_driver::type_id::create("dll_driver", this);
      dll_sequencer = tl_dll_sequencer::type_id::create("dll_sequencer", this);
    end

    dll_monitor = tl_dll_monitor::type_id::create("dll_monitor", this);
  endfunction


  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(is_active == UVM_ACTIVE) begin
      dll_driver.seq_item_port.connect(dll_sequencer.seq_item_export);
    end
      if(monitor_cpl) begin
        dll_monitor.reactive_sqr = dll_sequencer;
    end
  endfunction

endclass : tl_dll_agent

`endif // TL_DLL_AGENT_SV