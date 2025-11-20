`ifndef TL_ENV_SV
`define TL_ENV_SV


class tl_env extends uvm_env;

  `uvm_component_utils(tl_env);

  // Agent handle
  tl_tx_agent tl_tx_agent; // Transmit agent
  tl_dll_agent tl_dll_agent; // DLL agent

  // Constructor
  function new(string name = "tl_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create agent
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(uvm_bitstream_t)::set(this, "tl_tx_agent", "is_active", UVM_ACTIVE);
    uvm_config_db#(uvm_bitstream_t)::set(this, "tl_dll_agent", "is_active", !UVM_ACTIVE);
    tl_tx_agent = tl_tx_agent::type_id::create("tl_tx_agent", this);
    tl_dll_agent = tl_dll_agent::type_id::create("tl_dll_agent", this);
  endfunction : build_phase

endclass : tl_env