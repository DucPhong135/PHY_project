`ifndef TL_CPL_TEST_SV
`define TL_CPL_TEST_SV


class tl_cpl_test extends uvm_test;

  `uvm_component_utils(tl_cpl_test);


  tl_tb cpl_tb;


  function new(string name = "tl_cpl_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    uvm_config_db#(bit)::set(this, "cpl_tb", "tx_scoreboard_enabled", 1'b1);
    uvm_config_db#(bit)::set(this, "cpl_tb", "rx_scoreboard_enabled", 1'b0);
    uvm_config_db#(bit)::set(this, "cpl_tb", "cpl_scoreboard_enabled", 1'b1);
    uvm_config_db#(bit)::set(this, "cpl_tb.dll_env.*", "monitor_cpl", 1'b1);
    uvm_config_db#(bit)::set(this, "cpl_tb.user_env.*","monitor_cpl", 1'b1);
    cpl_tb = tl_tb::type_id::create("cpl_tb", this);

    uvm_config_db#(uvm_object_wrapper)::set(this, "cpl_tb.user_env.user_agent.user_sequencer.run_phase", "default_sequence", tx_seq::get_type());
    uvm_config_db#(uvm_object_wrapper)::set(this, "cpl_tb.dll_env.dll_agent.dll_sequencer.run_phase", "default_sequence", cpl_sequence::get_type());
  endfunction : build_phase
  
  function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
  endfunction : end_of_elaboration_phase

  task run_phase(uvm_phase phase);
    uvm_objection obj = phase.get_objection();
    obj.set_drain_time(this, 100ns);
    `uvm_info("CPL_TEST", "Starting TL CPL Test", UVM_LOW);
  endtask : run_phase
endclass : tl_cpl_test

`endif 