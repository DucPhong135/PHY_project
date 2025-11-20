`ifndef TL_TX_TEST_SV
`define TL_TX_TEST_SV




class tl_tx_test extends uvm_test;

  `uvm_component_utils(tl_tx_test);

  // Testbench handle
  tl_tx_tb tl_tx_tb;

  // Constructor
  function new(string name = "tl_tx_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: create testbench
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tl_tx_tb = tl_tx_tb::type_id::create("tl_tx_tb", this);
  endfunction : 
  
  function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase
endclass : tl_tx_test

`endif // TL_TX_TEST_SV