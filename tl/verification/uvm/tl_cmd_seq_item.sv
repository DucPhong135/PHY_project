`ifndef TL_CMD_SEQ_ITEM_SV
`define TL_CMD_SEQ_ITEM_SV



class tl_cmd_seq_item extends uvm_sequence_item;
  
  `uvm_object_utils(tl_cmd_seq_item)
  
  //------------------------------------------------------------------
  // Command Fields
  //------------------------------------------------------------------
  rand tl_cmd_type_e trans_type;
  rand bit        is_write;
  rand bit [63:0] addr;
  rand bit [9:0]  length_dw;  // Length in DWs
  rand bit [3:0]  first_be;
  rand bit [3:0]  last_be;
  rand bit [7:0]  tag;
  
  //------------------------------------------------------------------
  // Data Payload (for writes)
  //------------------------------------------------------------------
  rand bit [31:0] data_payload[$];  // Queue of DWs
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  constraint valid_trans_type_c {
    trans_type inside {tl_pkg::CMD_MEM, tl_pkg::CMD_CFG};
  }
  
  constraint valid_length_c {
    length_dw inside {[1:256]};
  }
  
  constraint valid_addr_c {
    addr[1:0] == 2'b00;  // DW aligned
  }
  
  // Data payload must match length for writes
  constraint data_length_c {
    if (is_write) {
      data_payload.size() == length_dw;
    } else {
      data_payload.size() == 0;
    }
  }
  
  constraint valid_be_c {
    first_be dist {4'b0001 := 1, 4'b0011 := 1, 4'b0111 := 1, 4'b1111 := 7};
    if (length_dw == 1) {
      last_be == 4'b0000;
    } else {
      last_be dist {4'b0001 := 1, 4'b0011 := 1, 4'b0111 := 1, 4'b1111 := 7};
    }
  }
  
  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  function new(string name = "tl_cmd_seq_item");
    super.new(name);
  endfunction
  
  //------------------------------------------------------------------
  // Convert to hardware command type
  //------------------------------------------------------------------
  function tl_pkg::tl_cmd_t to_tl_cmd();
    tl_pkg::tl_cmd_t cmd;
    
    cmd.cmd_type  = trans_type;
    cmd.is_write  = is_write;
    cmd.addr      = addr;
    cmd.length_dw = length_dw;
    cmd.first_be  = first_be;
    cmd.last_be   = last_be;
    cmd.tag       = tag;
    
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
  // Get number of data beats needed
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
    printer.print_field("Address", addr, 64, UVM_HEX);
    printer.print_field("Length (DW)", length_dw, 10, UVM_DEC);
    printer.print_field("First BE", first_be, 4, UVM_BIN);
    printer.print_field("Last BE", last_be, 4, UVM_BIN);
    printer.print_field("Tag", tag, 8, UVM_HEX);
    if (is_write) begin
      printer.print_field("Data DWs", data_payload.size(), 32, UVM_DEC);
    end
  endfunction

endclass : tl_cmd_seq_item

`endif // TL_CMD_SEQ_ITEM_SV