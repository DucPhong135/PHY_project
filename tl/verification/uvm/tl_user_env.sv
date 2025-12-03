`ifndef TL_ENV_SV
`define TL_ENV_SV


class tl_user_env extends uvm_env;

  `uvm_component_utils(tl_user_env);

  // Agent handle
  tl_user_agent user_agent; // Transmit agent

  // Constructor
  function new(string name = "tl_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create agent
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_bitstream_t)::set(this, "user_agent", "is_active", UVM_ACTIVE);
    user_agent = tl_user_agent::type_id::create("user_agent", this);
  endfunction : build_phase

endclass : tl_user_env

`endif