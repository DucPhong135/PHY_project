#ifndef TL_TX_AGENT_SV
#define TL_TX_AGENT_SV


class tl_tx_agent extends uvm_agent;

  `uvm_component_utils(tl_tx_agent);

  // Sequencer and Driver handles
  tl_tx_sequencer tl_tx_sequencer;
  tl_tx_driver       tl_tx_driver;
  tl_tx_monitor      tl_tx_monitor;

  // Constructor
  function new(string name = "tl_tx_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create sequencer and driver
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(is_active == UVM_ACTIVE) begin
        tl_tx_sequencer = tl_tx_sequencer::type_id::create("tl_tx_sequencer", this);
        tl_tx_driver    = tl_tx_driver::type_id::create("tl_tx_driver", this);
    end
    tl_tx_monitor   = tl_tx_monitor::type_id::create("tl_tx_monitor", this);
  endfunction : build_phase

  // Connect phase: connect sequencer to driver
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(is_active == UVM_ACTIVE) begin
        tl_tx_driver.seq_item_port.connect(tl_tx_sequencer.seq_item_export);
    end
  endfunction : connect_phase
endclass : tl_tx_agent