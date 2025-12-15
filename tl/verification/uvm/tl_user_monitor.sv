`ifndef TL_MONITOR_SV
`define TL_MONITOR_SV



class tl_user_monitor extends uvm_monitor;

`uvm_component_utils(tl_user_monitor);


  // Virtual interface to DUT signals
  virtual tl_user_if vif;
  uvm_analysis_port #(tl_user_seq_item) monitor_ap;


  uvm_analysis_port #(tl_user_seq_item) cpl_ap;


  // Constructor
  function new(string name = "tl_user_monitor", uvm_component parent = null);
    super.new(name, parent);
    monitor_ap = new("monitor_ap", this);
    cpl_ap     = new("cpl_ap", this);
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
    fork
      monitor_commands();
      monitor_mem_rd_completions();
      monitor_cfg_rd_completions();
      monitor_cfg_wr_completions();
    join
  endtask : run_phase

  task monitor_commands();
    tl_user_seq_item user_item;
    forever begin
      @(posedge vif.clk);
      if(vif.cmd_valid && vif.cmd_ready) begin
        user_item = tl_user_seq_item::type_id::create("cmd_item");
        collect_command(user_item);
        monitor_ap.write(user_item);
      end
    end
  endtask : monitor_commands
  

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
    item.config_data  = cmd.config_data;
    
    if (item.is_write && item.trans_type == CMD_MEM) begin
      collect_write_data(item);
    end
    
  endtask : collect_command

  task collect_write_data(tl_user_seq_item item);
  
    item.data_payload.delete();

    while (item.data_payload.size() < item.length_dw) begin
      @(posedge vif.clk);
      if (vif.wready && vif.wvalid) begin
        item.data_payload.push_back(vif.wdata[31:0]);
      end
    end
  endtask : collect_write_data

  task monitor_mem_rd_completions();
    tl_user_seq_item cpl_item;
    forever begin
      @(posedge vif.clk);
      vif.usr_read_rp_ready_i = 1'b1; // Always ready to accept data
      if(vif.usr_read_rp_ready_i && vif.usr_read_rp_valid_o) begin
        // Start of new memory read completion
        cpl_item = tl_user_seq_item::type_id::create("mem_rd_cpl");
        `uvm_info("TL_USER_MON", "Detected Memory Read Completion Request", UVM_LOW)
        vif.usr_read_rp_ready_i = 1'b0;
        collect_mem_rd_completion(cpl_item);
        
        `uvm_info("TL_USER_MON", $sformatf(
            "Captured Memory Read Completion data:"
        ), UVM_LOW)

        cpl_item.print();
        cpl_ap.write(cpl_item);
      end
    end
  endtask : monitor_mem_rd_completions


  virtual task collect_mem_rd_completion(tl_user_seq_item item);
    bit done = 0;
    
    // Capture first beat (already validated sop)
    item.trans_type = CMD_MEM;
    item.is_write   = 1'b0;
    item.addr       = vif.usr_read_rp_addr_o;
    item.length_dw  = vif.usr_read_rp_length_o;
    item.first_be   = vif.usr_first_be_o;
    item.last_be    = vif.usr_last_be_o;
    item.is_response = 1'b1;
    
    item.data_payload.delete();
    
    vif.usr_rready_i = 1'b1;
    // Collect remaining beats
  while (!done) begin
    @(posedge vif.clk);
    vif.usr_rready_i = 1'b1;  // Keep ready asserted continuously
    
    if (vif.usr_rvalid_o && vif.usr_rready_i) begin
      item.data_payload.push_back(vif.usr_rdata_o[31:0]);
      if (vif.usr_reop_o) begin
        done = 1;
      end
      // Don't add extra clock edge or deassert ready here
    end
  end

// Clean up after loop
  vif.usr_rready_i = 1'b0;
    
  endtask : collect_mem_rd_completion


  

task monitor_cfg_rd_completions();
    tl_user_seq_item cpl_item;
    forever begin
      @(posedge vif.clk);
      vif.cfg_rd_ready_i = 1'b1;
      if(vif.cfg_rd_valid_o && vif.cfg_rd_ready_i) begin
        cpl_item = tl_user_seq_item::type_id::create("cfg_rd_cpl");
        
        cpl_item.trans_type = CMD_CFG;
        cpl_item.is_write   = 1'b0;
        cpl_item.length_dw  = 1;
        cpl_item.tag      = vif.cfg_rd_tag_o;
        cpl_item.status   = vif.cfg_rd_status_o;
        cpl_item.bus      = vif.cfg_rd_bus_number_o;
        cpl_item.device   = vif.cfg_rd_device_number_o;
        cpl_item.function_num = vif.cfg_rd_function_number_o;
        cpl_item.is_response = 1'b1;

        // Config read returns 1 DW
        cpl_item.data_payload.delete();
        cpl_item.data_payload.push_back(vif.cfg_rd_data_o);
        
        `uvm_info("TL_USER_MON", $sformatf(
          "Captured Config Read Completion:"
        ), UVM_LOW)
        
        cpl_item.print();
        cpl_ap.write(cpl_item);
        vif.cfg_rd_ready_i = 1'b0;
      end
      
    end
  endtask : monitor_cfg_rd_completions

  task monitor_cfg_wr_completions();
    tl_user_seq_item cpl_item;
    forever begin
      @(posedge vif.clk);
      vif.cfg_wr_ready_i = 1'b1;
      if(vif.cfg_wr_valid_o && vif.cfg_wr_ready_i) begin
        cpl_item = tl_user_seq_item::type_id::create("cfg_wr_cpl");
        
        cpl_item.trans_type = CMD_CFG;
        cpl_item.is_write   = 1'b1;
        cpl_item.length_dw  = 0;  // No data for config write completion
        cpl_item.tag      = vif.cfg_wr_tag_o;
        cpl_item.status   = vif.cfg_wr_status_o;
        cpl_item.bus      = vif.cfg_wr_bus_number_o;
        cpl_item.device   = vif.cfg_wr_device_number_o;
        cpl_item.function_num = vif.cfg_wr_function_number_o;
        cpl_item.is_response = 1'b1;
        
        cpl_item.data_payload.delete();
        
        `uvm_info("TL_USER_MON", $sformatf(
          "Captured Config Write Completion:"
        ), UVM_LOW)
        
        cpl_item.print();
        cpl_ap.write(cpl_item);
        vif.cfg_wr_ready_i = 1'b0;
      end
    end
  endtask : monitor_cfg_wr_completions

endclass : tl_user_monitor

`endif