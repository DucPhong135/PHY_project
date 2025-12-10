`ifndef TL_TX_TEST_SV
`define TL_TX_TEST_SV


class tl_tx_test extends uvm_test;

  `uvm_component_utils(tl_tx_test);

  // Testbench handle
  tl_tb tx_tb;


  // Constructor
  function new(string name = "tl_tx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create testbench
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(bit)::set(this, "tx_tb", "tx_scoreboard_enabled", 1'b1);
    uvm_config_db#(bit)::set(this, "tx_tb", "rx_scoreboard_enabled", 1'b0);
    tx_tb = tl_tb::type_id::create("tx_tb", this);

    uvm_config_db#(uvm_object_wrapper)::set(this, "tx_tb.user_env.user_agent.user_sequencer.run_phase", "default_sequence", tx_seq::get_type());
  endfunction : build_phase
  
  function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  task run_phase(uvm_phase phase);
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 100ns); // Allow 100ns for cleanup
    `uvm_info("TX_TEST", "Starting TL TX Test", UVM_LOW);
  endtask : run_phase
endclass : tl_tx_test

`endif // TL_TX_TEST_SV