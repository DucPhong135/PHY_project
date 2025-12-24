`ifndef TL_TX_SEQUENCER_SV
`define TL_TX_SEQUENCER_SV




class tl_user_sequencer extends uvm_sequencer #(tl_user_seq_item);

  `uvm_component_utils(tl_user_sequencer);

  function new(string name = "tl_user_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass : tl_user_sequencer

`endif