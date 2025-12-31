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
  int dws_remaining;
  int dws_this_beat;
  
  item.data_payload.delete();

  while (item.data_payload.size() < item.length_dw) begin
    @(posedge vif.clk);
    if (vif.wready && vif.wvalid) begin
      
      // Calculate how many DWs remaining
      dws_remaining = item.length_dw - item.data_payload.size();
      
      // Determine how many DWs to collect from this beat (max 4)
      dws_this_beat = (dws_remaining > 4) ? 4 : dws_remaining;
      
      // Extract only the needed DWs
      case (dws_this_beat)
        4: begin
          item.data_payload.push_back(vif.wdata[31:0]);
          item.data_payload.push_back(vif.wdata[63:32]);
          item.data_payload.push_back(vif.wdata[95:64]);
          item.data_payload.push_back(vif.wdata[127:96]);
        end
        3: begin
          item.data_payload.push_back(vif.wdata[31:0]);
          item.data_payload.push_back(vif.wdata[63:32]);
          item.data_payload.push_back(vif.wdata[95:64]);
        end
        2: begin
          item.data_payload.push_back(vif.wdata[31:0]);
          item.data_payload.push_back(vif.wdata[63:32]);
        end
        1: begin
          item.data_payload.push_back(vif.wdata[31:0]);
        end
        default: begin
          `uvm_error("TL_USER_MON", $sformatf("Invalid DWs to collect: %0d", dws_this_beat))
        end
      endcase
    end
  end
  
  // Verify we collected the correct amount
  if (item.data_payload.size() != item.length_dw) begin
    `uvm_warning("TL_USER_MON", $sformatf(
      "Write data size mismatch: expected %0d DWs, got %0d DWs",
      item.length_dw, item.data_payload.size()))
  end
  
endtask : collect_write_data

  task monitor_mem_rd_completions();
    tl_user_seq_item cpl_item;
    forever begin
      @(posedge vif.clk);
      vif.usr_read_rp_ready_i = 1'b1;
      if(vif.usr_read_rp_ready_i && vif.usr_read_rp_valid_o) begin
        cpl_item = tl_user_seq_item::type_id::create("mem_rd_cpl");
        `uvm_info("TL_USER_MON", "Detected Memory Read Completion Request", UVM_HIGH)
        vif.usr_read_rp_ready_i = 1'b0;
        collect_mem_rd_completion(cpl_item);
        
        `uvm_info("TL_USER_MON", $sformatf(
            "Captured Memory Read Completion data:"
        ), UVM_HIGH)

        if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "TL_USER_MON")) begin
            cpl_item.print();
        end
        cpl_ap.write(cpl_item);
      end
    end
  endtask : monitor_mem_rd_completions


  virtual task collect_mem_rd_completion(tl_user_seq_item item);
  bit done = 0;
  int total_beats;
  int current_beat = 0;
  int dws_to_collect;
  
  item.trans_type = CMD_MEM;
  item.is_write   = 1'b0;
  item.addr       = vif.usr_read_rp_addr_o;
  item.length_dw  = vif.usr_read_rp_length_o;
  item.first_be   = vif.usr_first_be_o;
  item.last_be    = vif.usr_last_be_o;
  item.is_response = 1'b1;
  
  item.data_payload.delete();
  
  total_beats = (item.length_dw + 3) / 4;
  
  vif.usr_rready_i = 1'b1;
  
  // Collect all beats
  while (!done) begin
    @(posedge vif.clk);
    vif.usr_rready_i = 1'b1;
    
    if (vif.usr_rvalid_o && vif.usr_rready_i) begin
      current_beat++;
      
      // Determine how many DWs to extract from this beat
      if (vif.usr_reop_o || current_beat == total_beats) begin
        dws_to_collect = item.length_dw - item.data_payload.size();
        done = 1;
      end else begin
        dws_to_collect = 4;
      end
      
      // Extract the appropriate number of DWs
      case (dws_to_collect)
        4: begin
          item.data_payload.push_back(vif.usr_rdata_o[31:0]);
          item.data_payload.push_back(vif.usr_rdata_o[63:32]);
          item.data_payload.push_back(vif.usr_rdata_o[95:64]);
          item.data_payload.push_back(vif.usr_rdata_o[127:96]);
        end
        3: begin
          item.data_payload.push_back(vif.usr_rdata_o[31:0]);
          item.data_payload.push_back(vif.usr_rdata_o[63:32]);
          item.data_payload.push_back(vif.usr_rdata_o[95:64]);
        end
        2: begin
          item.data_payload.push_back(vif.usr_rdata_o[31:0]);
          item.data_payload.push_back(vif.usr_rdata_o[63:32]);
        end
        1: begin
          item.data_payload.push_back(vif.usr_rdata_o[31:0]);
        end
        default: begin
          `uvm_error("TL_USER_MON", $sformatf("Invalid DWs to collect: %0d", dws_to_collect))
        end
      endcase
      
      if (vif.usr_reop_o) begin
        done = 1;
      end
    end
  end
  
  vif.usr_rready_i = 1'b0;
  
  if (item.data_payload.size() != item.length_dw) begin
    `uvm_warning("TL_USER_MON", $sformatf(
      "Data size mismatch: expected %0d DWs, got %0d DWs",
      item.length_dw, item.data_payload.size()))
  end
  
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

        cpl_item.data_payload.delete();
        cpl_item.data_payload.push_back(vif.cfg_rd_data_o);
        
        `uvm_info("TL_USER_MON", $sformatf(
          "Captured Config Read Completion:"
        ), UVM_HIGH)
        
        if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "TL_USER_MON")) begin
            cpl_item.print();
        end
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
        cpl_item.length_dw  = 0;  
        cpl_item.tag      = vif.cfg_wr_tag_o;
        cpl_item.status   = vif.cfg_wr_status_o;
        cpl_item.bus      = vif.cfg_wr_bus_number_o;
        cpl_item.device   = vif.cfg_wr_device_number_o;
        cpl_item.function_num = vif.cfg_wr_function_number_o;
        cpl_item.is_response = 1'b1;
        
        cpl_item.data_payload.delete();
        
        `uvm_info("TL_USER_MON", $sformatf(
          "Captured Config Write Completion:"
        ), UVM_HIGH)
        
        if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "TL_USER_MON")) begin
            cpl_item.print();
        end
        cpl_ap.write(cpl_item);
        vif.cfg_wr_ready_i = 1'b0;
      end
    end
  endtask : monitor_cfg_wr_completions

endclass : tl_user_monitor

`endif