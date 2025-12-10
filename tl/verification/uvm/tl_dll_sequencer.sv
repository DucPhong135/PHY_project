`ifndef TL_DLL_SEQUENCER_SV
`define TL_DLL_SEQUENCER_SV

class tl_dll_sequencer extends uvm_sequencer#(tl_tlp_seq_item);

    `uvm_component_utils(tl_dll_sequencer)
    
    function new(string name = "tl_dll_sequencer", uvm_component parent = null);
        super.new(name, parent);
    endfunction
endclass : tl_dll_sequencer
`endif // TL_DLL_SEQUENCER_SV