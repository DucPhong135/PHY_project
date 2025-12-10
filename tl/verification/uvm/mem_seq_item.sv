class mem_sequence_item extends uvm_sequence_item;
  
  rand bit        is_write;
  rand bit[63:0]  addr;
  rand bit[9:0]   length;
  rand bit[3:0]   first_be;
  rand bit[3:0]   last_be;
  rand bit[127:0] data_queue[$];
  bit[31:0]       payload_data[$];

  `uvm_object_utils_begin(mem_sequence_item)
    `uvm_field_int(is_write, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(addr, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(length, UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(first_be, UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(last_be, UVM_ALL_ON | UVM_BIN)
    `uvm_field_queue_int(data_queue, UVM_ALL_ON | UVM_HEX)
    `uvm_field_queue_int(payload_data, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  function new(string name = "mem_sequence_item");
    super.new(name);
  endfunction

  function bit is_read();
    return !is_write;
  endfunction

endclass