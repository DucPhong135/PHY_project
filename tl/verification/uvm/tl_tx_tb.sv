`ifndef TL_TB_SV
`define TL_TB_SV


class tl_tx_tb extends uvm_env;
    `uvm_component_utils(tl_tx_tb);
    
    // Environment handle
    tl_env env;
    
    // Constructor
    function new(string name = "tl_tx_tb", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    // Build phase: create environment
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = tl_env::type_id::create("env", this);
    endfunction : build_phase
endclass : tl_tx_tb

`endif