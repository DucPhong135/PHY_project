`ifndef TL_USER_DRIVER_SV
`define TL_USER_DRIVER_SV

class tl_user_driver extends uvm_driver #(tl_user_seq_item);
  
  `uvm_component_utils(tl_user_driver)
  
  virtual tl_user_if vif;
  // uvm_analysis_port #(tl_user_seq_item) ap;
  
  function new(string name = "tl_user_driver", uvm_component parent = null);
    super.new(name, parent);
    // ap = new("ap", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_user_if)::get(this, "", "user_vif", vif)) begin
      `uvm_fatal("USER_DRV", "Virtual interface not found")
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    // Initialize signals
    vif.init_signals();
    
    // Wait for reset
    vif.wait_for_reset();
    `uvm_info("USER_DRV", "Reset complete, starting driver", UVM_LOW);
    forever begin
      seq_item_port.get_next_item(req);
      
      // // Send to scoreboard
      // ap.write(req);
      
      // Drive transaction
      drive_transaction(req);
      
      seq_item_port.item_done();
    end
  endtask
  
  //------------------------------------------------------------------
  // Convert UVM item to hardware types and drive
  //------------------------------------------------------------------
  task drive_transaction(tl_user_seq_item item);
    tl_cmd_t hw_cmd;
    tl_data_t beat_queue[$];  // ✅ Use unpacked queue
    
    hw_cmd = item.to_tl_cmd();
    
    // Step 2: Send command
    vif.send_command(hw_cmd);
    
    // Step 3: Send data (if write)
    if (item.is_write) begin
      // Convert payload to hardware beats
      convert_to_beats(item, beat_queue);  // ✅ Pass queue by reference
      vif.send_write_beats(beat_queue);
    end
    
    `uvm_info("USER_DRV", $sformatf("Sent %s: Addr=0x%0h, Len=%0d DW", 
              item.trans_type.name(), item.addr, item.length_dw), UVM_MEDIUM)
  endtask
  
  //------------------------------------------------------------------
  // Convert UVM payload to hardware beats (pass queue by reference)
  //------------------------------------------------------------------
  task convert_to_beats(tl_user_seq_item item, ref tl_data_t beats[$]);
    tl_data_t beat;
    int num_beats;
    
    beats.delete();  // Clear output queue
    num_beats = item.get_num_beats();
    
    for (int i = 0; i < num_beats; i++) begin
      // ✅ Assign fields individually to avoid packed/unpacked mismatch
      beat.data = item.get_data_beat(i);
      beat.sop  = (i == 0) ? 1'b1 : 1'b0;
      beat.eop  = (i == num_beats - 1) ? 1'b1 : 1'b0;
      beat.be   = 16'hFFFF;
      
      beats.push_back(beat);
    end
  endtask
  
endclass : tl_user_driver

`endif // TL_USER_DRIVER_SV