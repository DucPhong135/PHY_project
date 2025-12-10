`ifndef TL_RX_TEST_SV
`define TL_RX_TEST_SV


class tl_rx_test extends uvm_test;
  `uvm_component_utils(tl_rx_test);

  // Testbench handle
  tl_tb rx_tb;

  // Constructor
  function new(string name = "tl_rx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create testbench
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(bit)::set(this, "rx_tb", "tx_scoreboard_enabled", 1'b0);
    uvm_config_db#(bit)::set(this, "rx_tb", "rx_scoreboard_enabled", 1'b1);
    rx_tb = tl_tb::type_id::create("rx_tb", this);

    uvm_config_db#(uvm_object_wrapper)::set(this, "rx_tb.dll_env.dll_agent.dll_sequencer.run_phase", "default_sequence", rx_seq::get_type());
  endfunction : build_phase
  
  function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  task run_phase(uvm_phase phase);
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 200ns); // Allow 200ns for cleanup
    `uvm_info("RX_TEST", "Starting TL RX Test", UVM_LOW);
  endtask : run_phase
endclass : tl_rx_test

`endif // TL_RX_TEST_SV