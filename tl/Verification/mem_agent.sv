class mem_agent extends uvm_agent;
  `uvm_component_utils(mem_agent)
  
  mem_monitor monitor;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = mem_monitor::type_id::create("monitor", this);
  endfunction
  
endclass