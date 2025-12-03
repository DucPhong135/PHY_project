`ifndef TL_TB_SV
`define TL_TB_SV


class tl_tx_tb extends uvm_env;
    `uvm_component_utils(tl_tx_tb);
    
    // Environment handle
    tl_user_env user_env;
    tl_dll_env dll_env;
    tx_scoreboard scoreboard;
    
    // Constructor
    function new(string name = "tl_tx_tb", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    // Build phase: create environment
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        user_env = tl_user_env::type_id::create("user_env", this);
        dll_env = tl_dll_env::type_id::create("dll_env", this);
        scoreboard = tx_scoreboard::type_id::create("scoreboard", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        
        // Connect user monitor to scoreboard
        user_env.user_agent.user_monitor.monitor_ap.connect(scoreboard.user_ap);
        
        // Connect DLL monitor to scoreboard
        dll_env.dll_agent.dll_monitor.monitor_ap.connect(scoreboard.dll_ap);
    endfunction : connect_phase
endclass : tl_tx_tb

`endif