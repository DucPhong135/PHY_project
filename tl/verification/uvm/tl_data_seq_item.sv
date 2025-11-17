`ifndef TL_DATA_SEQ_ITEM_SV
`define TL_DATA_SEQ_ITEM_SV

class tl_data_seq_item extends uvm_sequence_item;
  
  //------------------------------------------------------------------
  // Data Fields (match tl_data_t)
  //------------------------------------------------------------------
  
  rand bit [127:0] data;       // 128-bit payload (4 DWs)
  rand bit [63:0]  addr;       // Address for this beat
  rand bit [15:0]  be;         // Byte enables (16 bits for 16 bytes)
  rand bit         sop;        // Start of packet
  rand bit         eop;        // End of packet
  
  // For multi-beat transfers, store multiple beats
  rand bit [127:0] data_queue[$];  // Queue of data beats
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  
  // Data pattern constraints
  constraint c_data {
    // Can be random, or you can add patterns
    // Leave unconstrained for maximum randomness
  }
  
  // Byte enable constraints
  constraint c_be {
    // Typically all bytes valid
    be dist {
      16'hFFFF := 90,  // 90% all bytes valid
      [1:16'hFFFE] := 10  // 10% partial bytes
    };
  }
  
  // Address should be aligned to beat boundary (16 bytes)
  constraint c_addr {
    addr[3:0] == 4'h0;  // 16-byte aligned
  }
  
  //------------------------------------------------------------------
  // UVM Automation Macros
  //------------------------------------------------------------------
  
  `uvm_object_utils_begin(tl_data_seq_item)
    `uvm_field_int(data,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(addr,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(be,    UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(sop,   UVM_ALL_ON)
    `uvm_field_int(eop,   UVM_ALL_ON)
    `uvm_field_queue_int(data_queue, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  
  function new(string name = "tl_data_seq_item");
    super.new(name);
  endfunction
  
  //------------------------------------------------------------------
  // Convert to tl_data_t (for driving DUT)
  //------------------------------------------------------------------
  
  function tl_pkg::tl_data_t to_tl_data();
    tl_pkg::tl_data_t wdata;
    
    wdata.data = data;
    wdata.addr = addr;
    wdata.be   = be;
    wdata.sop  = sop;
    wdata.eop  = eop;
    
    return wdata;
  endfunction
  
  //------------------------------------------------------------------
  // Utility: Generate write data for a command
  //------------------------------------------------------------------
  
  // Generate data beats based on command length
  function void gen_data_for_cmd(tl_cmd_seq_item cmd);
    int num_beats;
    bit [63:0] base_addr;
    
    data_queue.delete();
    
    // Calculate number of 128-bit beats (4 DWs per beat)
    num_beats = (cmd.length_dw + 3) / 4;
    base_addr = cmd.addr & 64'hFFFF_FFFF_FFFF_FFF0;  // 16-byte aligned
    
    for (int i = 0; i < num_beats; i++) begin
      // Generate random or patterned data
      data_queue.push_back($urandom() | ($urandom() << 32) | 
                          (bit'($urandom()) << 64) | (bit'($urandom()) << 96));
    end
    
    // Set first beat parameters
    if (data_queue.size() > 0) begin
      data = data_queue[0];
      addr = base_addr;
      sop  = 1'b1;
      eop  = (num_beats == 1);
      be   = 16'hFFFF;
    end
  endfunction
  
  // Generate sequential data pattern (for debug)
  function void gen_sequential_data(tl_cmd_seq_item cmd, bit [31:0] seed = 0);
    int num_beats;
    bit [63:0] base_addr;
    
    data_queue.delete();
    num_beats = (cmd.length_dw + 3) / 4;
    base_addr = cmd.addr & 64'hFFFF_FFFF_FFFF_FFF0;
    
    for (int i = 0; i < num_beats; i++) begin
      bit [127:0] beat_data;
      // Create pattern: each DW = seed + beat*4 + dw_offset
      beat_data[31:0]   = seed + (i*4) + 0;
      beat_data[63:32]  = seed + (i*4) + 1;
      beat_data[95:64]  = seed + (i*4) + 2;
      beat_data[127:96] = seed + (i*4) + 3;
      data_queue.push_back(beat_data);
    end
    
    if (data_queue.size() > 0) begin
      data = data_queue[0];
      addr = base_addr;
      sop  = 1'b1;
      eop  = (num_beats == 1);
      be   = 16'hFFFF;
    end
  endfunction
  
  // Generate constant data pattern
  function void gen_constant_data(tl_cmd_seq_item cmd, bit [31:0] pattern);
    int num_beats;
    bit [63:0] base_addr;
    
    data_queue.delete();
    num_beats = (cmd.length_dw + 3) / 4;
    base_addr = cmd.addr & 64'hFFFF_FFFF_FFFF_FFF0;
    
    for (int i = 0; i < num_beats; i++) begin
      data_queue.push_back({pattern, pattern, pattern, pattern});
    end
    
    if (data_queue.size() > 0) begin
      data = data_queue[0];
      addr = base_addr;
      sop  = 1'b1;
      eop  = (num_beats == 1);
      be   = 16'hFFFF;
    end
  endfunction

endclass : tl_data_seq_item

`endif // TL_DATA_SEQ_ITEM_SV