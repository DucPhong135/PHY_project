`ifndef TL_MONITOR_SV
`define TL_MONITOR_SV



class tl_user_monitor extends uvm_monitor;

`uvm_component_utils(tl_user_monitor);


  // Virtual interface to DUT signals
  virtual tl_user_if vif;

  // Constructor
  function new(string name = "tl_user_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: get virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual tl_user_if)::get(this, "", "user_vif", vif)) begin
      `uvm_fatal("TL_MONITOR", "Virtual interface not found")
    end
  endfunction : build_phase

  // Main run phase: monitor transactions
  task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk);
      // Monitor logic to capture transactions goes here
      // `uvm_info("TL_MONITOR", "Monitoring transaction...", UVM_LOW);
    end
  endtask : run_phase

endclass : tl_user_monitor

`endif