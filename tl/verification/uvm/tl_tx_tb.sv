#ifndef TL_TB_SV
#define TL_TB_SV


class tl_tb extends uvm_env;
    `uvm_component_utils(tl_tb);
    
    // Environment handle
    tl_env tl_env;
    
    // Constructor
    function new(string name = "tl_tb", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    // Build phase: create environment
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tl_env = tl_env::type_id::create("tl_env", this);
    endfunction : build_phase
endclass : tl_tb