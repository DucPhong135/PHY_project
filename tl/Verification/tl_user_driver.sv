`ifndef TL_USER_DRIVER_SV
`define TL_USER_DRIVER_SV

class tl_user_driver extends uvm_driver #(tl_user_seq_item);
  
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
  
  task run_phase(uvm_phase phase);
    vif.init_signals();
    
    vif.wait_for_reset();
    `uvm_info("USER_DRV", "Reset complete, starting driver", UVM_LOW);
    forever begin
      seq_item_port.get_next_item(req);
       
      drive_transaction(req);
      
      seq_item_port.item_done();
    end
  endtask
  
  //------------------------------------------------------------------
  // Convert UVM item to hardware types and drive
  //------------------------------------------------------------------
  task drive_transaction(tl_user_seq_item item);
    tl_cmd_t hw_cmd;
    logic [127:0] beat_queue[$];
    
    hw_cmd = item.to_tl_cmd();
    
    vif.send_command(hw_cmd);
    
    if (item.is_write && item.trans_type == CMD_MEM) begin
      // Convert payload to hardware beats
      convert_to_beats(item, beat_queue);
      `uvm_info("USER_DRV", $sformatf("Converted %0d data beats for write", beat_queue.size()), UVM_LOW);
      foreach (beat_queue[i]) begin
        `uvm_info("USER_DRV", $sformatf("  Beat %0d: 0x%0h", i, beat_queue[i]), UVM_LOW);
      end
      vif.send_write_beats(beat_queue);
    end
    
    `uvm_info("USER_DRV", $sformatf("Sent %s: Addr=0x%0h, Len=%0d DW", 
              item.trans_type.name(), item.addr, item.length_dw), UVM_MEDIUM)
  endtask
  
  //------------------------------------------------------------------
  // Convert UVM payload to hardware beats (pass queue by reference)
  //------------------------------------------------------------------
  task convert_to_beats(tl_user_seq_item item, ref logic [127:0] beats[$]);
    logic [127:0] beat;
    int num_beats;
    
    beats.delete();
    num_beats = item.get_num_beats();
    
    for (int i = 0; i < num_beats; i++) begin
      beat = item.get_data_beat(i);
      
      beats.push_back(beat);
    end
  endtask
  
endclass : tl_user_driver

`endif // TL_USER_DRIVER_SV