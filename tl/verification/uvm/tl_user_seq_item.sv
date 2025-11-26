`ifndef TL_USER_SEQ_ITEM_SV
`define TL_USER_SEQ_ITEM_SV

class tl_user_seq_item extends uvm_sequence_item;
  
  `uvm_object_utils(tl_user_seq_item)
  
  //------------------------------------------------------------------
  // Command Fields (matching tl_cmd_t structure)
  //------------------------------------------------------------------
  rand tl_cmd_type_e trans_type;
  rand bit [9:0]     length_dw;     // Length in DWs (1-1024)
  rand bit           is_write;      // 1 = Write, 0 = Read
  
  // Memory-specific fields
  rand bit [63:0]    addr;          // Byte address (for CMD_MEM)
  
  // Config-specific fields (for CMD_CFG)
  rand bit [7:0]     bus;           // Bus Number
  rand bit [4:0]     device;        // Device Number
  rand bit [2:0]     function_num;  // Function Number
  rand bit [9:0]     reg_num;       // Config register (DWORD aligned)
  
  // Note: first_be, last_be, tag removed as they're not in tl_cmd_t
  
  //------------------------------------------------------------------
  // Data Payload (for writes)
  //------------------------------------------------------------------
  rand bit [31:0] data_payload[$];  // Queue of DWs
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  constraint valid_trans_type_c {
    trans_type inside {CMD_MEM, CMD_CFG};
  }
  
  constraint valid_length_c {
    length_dw inside {[1:1024]};  // Updated to match tl_cmd_t range
  }
  
  
  // Config register constraints (only valid for CMD_CFG)
  constraint valid_cfg_c {
    if (trans_type == CMD_CFG) {
      reg_num[1:0] == 2'b00;  // DWORD aligned
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
  
  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  function new(string name = "tl_user_seq_item");
    super.new(name);
  endfunction
  
  //------------------------------------------------------------------
  // Convert to hardware command type (matching exact field names)
  //------------------------------------------------------------------
  function tl_cmd_t to_tl_cmd();
    tl_cmd_t cmd;
    
    // Match exact field names from tl_cmd_t
    cmd.type_cmd     = trans_type;
    cmd.len          = length_dw;
    cmd.wr_en        = is_write;
    cmd.addr         = addr;
    cmd.bus          = bus;
    cmd.device       = device;
    cmd.function_num = function_num;
    cmd.reg_num      = reg_num;
    
    return cmd;
  endfunction
  
  //------------------------------------------------------------------
  // Get data beat at index (4 DWs per 128-bit beat)
  //------------------------------------------------------------------
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
  
  //------------------------------------------------------------------
  // Get number of data beats needed (4 DWs per 128-bit beat)
  //------------------------------------------------------------------
  function int get_num_beats();
    return (length_dw + 3) / 4;  // Round up to 128-bit beats
  endfunction
  
  //------------------------------------------------------------------
  // UVM Print
  //------------------------------------------------------------------
  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_string("Type", trans_type.name());
    printer.print_field("Is Write", is_write, 1, UVM_BIN);
    printer.print_field("Length (DW)", length_dw, 10, UVM_DEC);
    
    if (trans_type == CMD_MEM) begin
      printer.print_field("Address", addr, 64, UVM_HEX);
    end else begin
      printer.print_field("Bus", bus, 8, UVM_HEX);
      printer.print_field("Device", device, 5, UVM_HEX);
      printer.print_field("Function", function_num, 3, UVM_HEX);
      printer.print_field("Reg Num", reg_num, 10, UVM_HEX);
    end
    
    if (is_write) begin
      printer.print_field("Data DWs", data_payload.size(), 32, UVM_DEC);
    end
  endfunction
  
  //------------------------------------------------------------------
  // UVM Copy
  //------------------------------------------------------------------
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
  
  //------------------------------------------------------------------
  // UVM Compare
  //------------------------------------------------------------------
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

endclass : tl_user_seq_item

`endif // TL_USER_SEQ_ITEM_SV