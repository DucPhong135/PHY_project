#ifndef TL_TX_SEQUENCER_SV
`define TL_TX_SEQUENCER_SV




class tl_tx_sequencer extends uvm_sequencer #(tl_tx_seq_item);

  `uvm_component_utils(tl_tx_sequencer);

  // Constructor
  function new(string name = "tl_tx_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : tl_tx_sequencer