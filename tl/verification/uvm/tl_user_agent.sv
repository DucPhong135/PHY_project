`ifndef TL_TX_AGENT_SV
`define TL_TX_AGENT_SV


class tl_user_agent extends uvm_agent;

  `uvm_component_utils(tl_user_agent);

  // Sequencer and Driver handles
  tl_user_sequencer user_sequencer;
  tl_user_driver    user_driver;
  tl_user_monitor   user_monitor;

  // Constructor
  function new(string name = "tl_user_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create sequencer and driver
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(is_active == UVM_ACTIVE) begin
        user_sequencer = tl_user_sequencer::type_id::create("user_sequencer", this);
        user_driver    = tl_user_driver::type_id::create("user_driver", this);
    end
    user_monitor   = tl_user_monitor::type_id::create("user_monitor", this);
  endfunction : build_phase

  // Connect phase: connect sequencer to driver
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(is_active == UVM_ACTIVE) begin
        user_driver.seq_item_port.connect(user_sequencer.seq_item_export);
    end
  endfunction : connect_phase
endclass : tl_user_agent

`endif