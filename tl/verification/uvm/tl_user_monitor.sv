`ifndef TL_MONITOR_SV
`define TL_MONITOR_SV



class tl_user_monitor extends uvm_monitor;

`uvm_component_utils(tl_user_monitor);


  // Virtual interface to DUT signals
  virtual tl_user_if vif;
  uvm_analysis_port #(tl_user_seq_item) monitor_ap;

  // Constructor
  function new(string name = "tl_user_monitor", uvm_component parent = null);
    super.new(name, parent);
    monitor_ap = new("monitor_ap", this);
  endfunction

  // Build phase: get virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual tl_user_if)::get(this, "", "user_vif", vif)) begin
      `uvm_fatal("TL_MONITOR", "Virtual interface not found")
    end
  endfunction : build_phase

  // Main run phase: monitor transactions
  task run_phase(uvm_phase phase);
    tl_user_seq_item user_item;
    forever begin
      @(posedge vif.clk);
      if(vif.cmd_valid && vif.cmd_ready) begin
        user_item = tl_user_seq_item::type_id::create("item");
        collect_command(user_item);
        // `uvm_info("TX_MON", "Captured User Transaction:", UVM_LOW);
        // user_item.print();
        monitor_ap.write(user_item);
      end
    end
  endtask : run_phase

  virtual task collect_command(tl_user_seq_item item);
    tl_cmd_t cmd;
    
    cmd = vif.cmd;
    
    item.trans_type   = cmd.type_cmd;
    item.is_write     = cmd.wr_en;
    item.addr         = cmd.addr;
    item.length_dw    = cmd.len;
    item.bus          = cmd.bus;
    item.device       = cmd.device;
    item.function_num = cmd.function_num;
    item.reg_num      = cmd.reg_num;
    
    if (item.is_write) begin
      collect_write_data(item);
    end
    
  endtask : collect_command

  //------------------------------------------------------------------
  // Collect Write Data from Interface
  //------------------------------------------------------------------
  
virtual task collect_write_data(tl_user_seq_item item);
    int data_count = 0;
    
    item.data_payload.delete();
    
    `uvm_info("TL_USER_MON", $sformatf(
        "Collecting %0d DW of write data...", item.length_dw), UVM_HIGH)
    
    // ✅ Collect all data beats - wait for actual handshakes
    while (data_count < item.length_dw) begin
        @(posedge vif.clk);
        
        // Only capture when both valid and ready are asserted
        if (vif.wvalid && vif.wready) begin
            item.data_payload.push_back(vif.wdata.data[31:0]);
            item.data_payload.push_back(vif.wdata.data[63:32]);
            item.data_payload.push_back(vif.wdata.data[95:64]);
            item.data_payload.push_back(vif.wdata.data[127:96]);
            if(data_count + 4 >= item.length_dw)
                data_count += item.length_dw - data_count; // Handle last partial beat
            else
                data_count += 4; // Each beat is 4 DW (128 bits)
            
            `uvm_info("TL_USER_MON", $sformatf(
                "  Captured write data[%0d/%0d]: 0x%08h", 
                data_count, item.length_dw, vif.wdata), UVM_HIGH)
        end
    end
    
    `uvm_info("TL_USER_MON", $sformatf(
        "Write data collection complete: %0d DW collected", 
        data_count), UVM_MEDIUM)
    
endtask : collect_write_data

endclass : tl_user_monitor

`endif