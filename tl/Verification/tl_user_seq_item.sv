`ifndef TL_USER_SEQ_ITEM_SV
`define TL_USER_SEQ_ITEM_SV

class tl_user_seq_item extends uvm_sequence_item;
  
  
  //------------------------------------------------------------------
  // Command Fields (matching tl_cmd_t structure)
  //------------------------------------------------------------------
  rand tl_cmd_type_e trans_type;
  rand bit [9:0]     length_dw;    // Length in DWs
  rand bit           is_write;
  

  rand bit [63:0]    addr;
  bit [3:0]     first_be;    
  bit [3:0]     last_be;      
  
  // Config-specific fields (for CMD_CFG)
  rand bit [7:0]     bus;           // Bus Number
  rand bit [4:0]     device;        // Device Number
  rand bit [2:0]     function_num;  // Function Number
  rand bit [9:0]     reg_num;       
  rand bit [31:0]    config_data;
  

  bit [7:0]    tag;           // Tag
  bit [2:0]    status;        // Completion status
  bit          is_response;  // Indicates if this is a response item
  
  rand bit [31:0] data_payload[$];  // Queue of DWs

  `uvm_object_utils_begin(tl_user_seq_item)
    `uvm_field_enum(tl_cmd_type_e, trans_type, UVM_ALL_ON)
    `uvm_field_int(length_dw, UVM_ALL_ON)
    `uvm_field_int(is_write, UVM_ALL_ON)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(first_be, UVM_ALL_ON)
    `uvm_field_int(last_be, UVM_ALL_ON)
    `uvm_field_int(bus, UVM_ALL_ON)
    `uvm_field_int(device, UVM_ALL_ON)
    `uvm_field_int(function_num, UVM_ALL_ON)
    `uvm_field_int(reg_num, UVM_ALL_ON)
    `uvm_field_int(config_data, UVM_ALL_ON)
    `uvm_field_queue_int(data_payload, UVM_ALL_ON)
    `uvm_field_int(tag, UVM_ALL_ON)
    `uvm_field_int(status, UVM_ALL_ON)
    `uvm_field_int(is_response, UVM_ALL_ON)
  `uvm_object_utils_end
  

  constraint valid_trans_type_c {
    trans_type inside {CMD_MEM, CMD_CFG};
  }
  
  constraint valid_length_c {
    length_dw inside {[1:1024]};
  }
  
  
  constraint valid_cfg_c {
    if (trans_type == CMD_CFG) {
      bus inside {[0:255]};
      device inside {[0:31]};
      function_num inside {[0:7]};
    } else {
      // Don't care for memory transactions
      bus == 8'h0;
      device == 5'h0;
      function_num == 3'h0;
      reg_num == 10'h0;
    }
  }
  
  // Data payload must match length for writes
  constraint data_length_c {
    if (is_write) {
      data_payload.size() == length_dw;
    } else {
      data_payload.size() == 0;
    }
  }

  constraint config_data_c {
    if(trans_type != CMD_CFG || is_write == 1'b0) {
      config_data == 32'h0;
    }
  }
  

  function new(string name = "tl_user_seq_item");
    super.new(name);
  endfunction
  

  function tl_cmd_t to_tl_cmd();
    tl_cmd_t cmd;
    
    cmd.type_cmd     = trans_type;
    cmd.len          = length_dw;
    cmd.wr_en        = is_write;
    cmd.addr         = addr;
    cmd.bus          = bus;
    cmd.device       = device;
    cmd.function_num = function_num;
    cmd.reg_num      = reg_num;
    cmd.config_data  = config_data;
    
    return cmd;
  endfunction
  

  function bit [127:0] get_data_beat(int beat_idx);
    bit [127:0] beat_data;
    int dw_start = beat_idx * 4;
    
    for (int i = 0; i < 4; i++) begin
      int dw_idx = dw_start + i;
      if (dw_idx < data_payload.size()) begin
        beat_data[i*32 +: 32] = data_payload[dw_idx];
      end else begin
        beat_data[i*32 +: 32] = 32'h0;
      end
    end
    
    return beat_data;
  endfunction
  

  function int get_num_beats();
    return (length_dw + 3) / 4; 
  endfunction
  

  function void do_print(uvm_printer printer);
    super.do_print(printer);
  endfunction
  

  function void do_copy(uvm_object rhs);
    tl_user_seq_item rhs_;
    
    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COPY", "Cast failed")
    end
    
    super.do_copy(rhs);
    
    trans_type   = rhs_.trans_type;
    length_dw    = rhs_.length_dw;
    is_write     = rhs_.is_write;
    addr         = rhs_.addr;
    bus          = rhs_.bus;
    device       = rhs_.device;
    function_num = rhs_.function_num;
    reg_num      = rhs_.reg_num;
    data_payload = rhs_.data_payload;
  endfunction
  

  function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    tl_user_seq_item rhs_;
    bit result;
    
    if (!$cast(rhs_, rhs)) begin
      `uvm_fatal("DO_COMPARE", "Cast failed")
      return 0;
    end
    
    result = super.do_compare(rhs, comparer);
    result &= (trans_type   == rhs_.trans_type);
    result &= (length_dw    == rhs_.length_dw);
    result &= (is_write     == rhs_.is_write);
    result &= (addr         == rhs_.addr);
    result &= (bus          == rhs_.bus);
    result &= (device       == rhs_.device);
    result &= (function_num == rhs_.function_num);
    result &= (reg_num      == rhs_.reg_num);
    result &= (data_payload == rhs_.data_payload);
    
    return result;
  endfunction

  function tl_user_seq_item get_current_command();
    return this;
  endfunction

endclass : tl_user_seq_item

`endif // TL_USER_SEQ_ITEM_SV