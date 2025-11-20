`ifndef TL_USER_DRIVER_SV
`define TL_USER_DRIVER_SV




class tl_user_driver extends uvm_driver #(tl_cmd_seq_item);
  
  `uvm_component_utils(tl_user_driver)
  
  virtual tl_user_if vif;
  
  function new(string name = "tl_user_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_user_if)::get(this, "", "user_vif", vif)) begin
      `uvm_fatal("USER_DRV", "Virtual interface not found")
    end
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if(!uvm_config_db#(virtual tl_user_if)::get(this, "", "user_vif", vif)) begin
      `uvm_fatal("USER_DRV", "Virtual interface not found during connect_phase")
    end
  endfunction

  task run_phase(uvm_phase phase);
    // Initialize signals
    vif.cmd_valid <= 1'b0;
    vif.cmd       <= '0;
    vif.wdata     <= '0;
    vif.wvalid    <= 1'b0;
    
    @(posedge vif.rst_n);  // Wait for reset
    
    forever begin
      seq_item_port.get_next_item(req);
      
      // Drive the transaction
      drive_transaction(req);
      
      seq_item_port.item_done();
    end
  endtask
  
  //------------------------------------------------------------------
  // Drive complete transaction (command + data)
  //------------------------------------------------------------------
  task drive_transaction(tl_cmd_seq_item item);
    tl_pkg::tl_cmd_t hw_cmd;
    
    // Step 1: Send command
    hw_cmd = item.to_tl_cmd();
    drive_command(hw_cmd);
    
    // Step 2: Send data (if write)
    if (item.is_write) begin
      drive_write_data(item);
    end
    
    `uvm_info("USER_DRV", $sformatf("Sent %s: Addr=0x%0h, Len=%0d DW", 
              item.trans_type.name(), item.addr, item.length_dw), UVM_MEDIUM)
  endtask
  
  //------------------------------------------------------------------
  // Drive command on usr_cmd_i interface
  //------------------------------------------------------------------
  task drive_command(tl_pkg::tl_cmd_t cmd);
    @(posedge vif.clk);
    vif.cmd       <= cmd;
    vif.cmd_valid <= 1'b1;
    
    // Wait for ready
    while (!vif.cmd_ready) begin
      @(posedge vif.clk);
    end
    
    // Deassert valid
    @(posedge vif.clk);
    vif.cmd_valid <= 1'b0;
  endtask
  
  //------------------------------------------------------------------
  // Drive write data on usr_wdata_i interface
  //------------------------------------------------------------------
  task drive_write_data(tl_cmd_seq_item item);
    int num_beats;
    tl_pkg::tl_data_t beat;
    
    num_beats = item.get_num_beats();
    
    for (int i = 0; i < num_beats; i++) begin
      // Prepare beat
      beat.data = item.get_data_beat(i);
      beat.sop  = (i == 0);
      beat.eop  = (i == num_beats - 1);
      beat.be   = 16'hFFFF;  // All bytes valid for simplicity
      
      // Drive beat
      @(posedge vif.clk);
      vif.wdata  <= beat;
      vif.wvalid <= 1'b1;
      
      // Wait for ready
      while (!vif.wready) begin
        @(posedge vif.clk);
      end
    end
    
    // Deassert valid
    @(posedge vif.clk);
    vif.wvalid <= 1'b0;
  endtask
  
endclass : tl_user_driver

`endif // TL_USER_DRIVER_SV