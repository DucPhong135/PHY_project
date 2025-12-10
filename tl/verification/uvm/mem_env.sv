// In your existing tl_user_env or create mem_env
class mem_env extends uvm_env;
  `uvm_component_utils(mem_env)
  
  mem_agent agent;
  tl_memory_model mem_model;  // Your responsive memory model
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = mem_agent::type_id::create("agent", this);
    mem_model = tl_memory_model::type_id::create("mem_model", this);
  endfunction
  
endclass