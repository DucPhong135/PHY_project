`ifndef TL_TB_SV
`define TL_TB_SV


class tl_tb extends uvm_env;
    `uvm_component_utils(tl_tb);

    bit tx_scoreboard_enabled = 1'b1;
    bit rx_scoreboard_enabled = 1'b1;
    
    // Environment handle
    tl_user_env user_env;
    tl_dll_env dll_env;
    mem_env memory_env;
    tx_scoreboard tx_scoreboard_inst;
    rx_scoreboard rx_scoreboard_inst;
    
    // Constructor
    function new(string name = "tl_tb", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    
    // Build phase: create environment
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        // Get scoreboard enable flag from config_db (default to enabled)
        if (!uvm_config_db#(bit)::get(this, "", "tx_scoreboard_enabled", tx_scoreboard_enabled)) begin
            tx_scoreboard_enabled = 1'b1;  // Default: enabled
            `uvm_info("TL_TB", "tx_scoreboard_enabled not set in config_db, defaulting to 1", UVM_LOW);
        end
        
        if (!uvm_config_db#(bit)::get(this, "", "rx_scoreboard_enabled", rx_scoreboard_enabled)) begin
            rx_scoreboard_enabled = 1'b1;  // Default: enabled
            `uvm_info("TL_TB", "rx_scoreboard_enabled not set in config_db, defaulting to 1", UVM_LOW);
        end
        user_env = tl_user_env::type_id::create("user_env", this);
        dll_env = tl_dll_env::type_id::create("dll_env", this);
        memory_env = mem_env::type_id::create("memory_env", this);
        if (tx_scoreboard_enabled) begin
            tx_scoreboard_inst = tx_scoreboard::type_id::create("tx_scoreboard_inst", this);
        end
        if (rx_scoreboard_enabled) begin
            rx_scoreboard_inst = rx_scoreboard::type_id::create("rx_scoreboard_inst", this);
        end
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (tx_scoreboard_enabled) begin
        // Connect user monitor to scoreboard
            user_env.user_agent.user_monitor.monitor_ap.connect(tx_scoreboard_inst.user_ap);
            
            // Connect DLL monitor to scoreboard
            dll_env.dll_agent.dll_monitor.tx_monitor_ap.connect(tx_scoreboard_inst.dll_ap);
        end

        if (rx_scoreboard_enabled) begin
        // Connect DLL monitor to scoreboard
            dll_env.dll_agent.dll_monitor.rx_monitor_ap.connect(rx_scoreboard_inst.rx_dll_in);
            dll_env.dll_agent.dll_monitor.tx_monitor_ap.connect(rx_scoreboard_inst.tx_dll_in);
            memory_env.mem_model.mem_ap.connect(rx_scoreboard_inst.mem_in);
        end
    endfunction : connect_phase
endclass : tl_tb

`endif