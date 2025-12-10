`ifndef TL_TLP_SEQ_ITEM_SV
`define TL_TLP_SEQ_ITEM_SV


class tl_tlp_seq_item extends uvm_sequence_item;
  
  //------------------------------------------------------------------
  // TLP Packet Fields (captured from tl_tx_o / tl_rx_i)
  //------------------------------------------------------------------
  // Raw TLP data stream
  bit [127:0] data_beats[$];  // Queue of 128-bit beats
  
  // Parsed TLP Header Fields
  rand bit [2:0]  fmt;                   // Format (3DW/4DW, with/without data)
  rand bit [4:0]  pkt_type;              // TLP type (MRd, MWr, CfgRd, CplD, etc.)
  rand bit [2:0]  tc;                    // Traffic Class
  rand bit [9:0]  length;                // Length in DWs
  rand bit [15:0] requester_id;          // Requester ID (Bus:Dev:Func)
  rand bit [7:0]  tag;                   // Transaction tag
  rand bit [63:0] address;               // address (32-bit or 64-bit)
  rand bit [3:0]  first_be;              // First DW Byte Enable
  rand bit [3:0]  last_be;               // Last DW Byte Enable
  
  // For Completions
  rand bit [15:0] completer_id;          // Completer ID
  rand bit [2:0]  status;                // Completion status
  rand bit [11:0] byte_count;            // Byte count
  rand bit [6:0]  lower_addr;
  

  //For config requests
  bit [7:0] bus_number;
  bit [4:0] device_number;
  bit [2:0] function_number;
  bit [11:0] register_number;
  // Payload data
  rand bit [31:0] payload_data[$];       // Queue of payload DWs
  
  //------------------------------------------------------------------
  // UVM Automation
  //------------------------------------------------------------------
  
  `uvm_object_utils_begin(tl_tlp_seq_item)
    `uvm_field_queue_int(data_beats, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(fmt,           UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(pkt_type,      UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(length,        UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(requester_id,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(tag,           UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(address,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(first_be,      UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(last_be,       UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(completer_id,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(status,        UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(byte_count,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(lower_addr,    UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(bus_number,    UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(device_number, UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(function_number,UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(register_number,UVM_ALL_ON | UVM_HEX)
    `uvm_field_queue_int(payload_data, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  
  // Length constraint: PCIe supports 1-1024 DWs
  constraint valid_length_c {
    length inside {[1:1024]};
  }

  // Packet type constraint: common PCIe TLP types
  constraint valid_pkt_type_c {
    pkt_type inside {
      5'b00000,  // Memory Read Request (MRd)
      5'b01010  // Completion without Data (Cpl)
    };
  }

  constraint fmt_pkt_type_consistency_c {
    fmt inside {3'b000, 3'b001, 3'b010, 3'b011};
  }


  // Requester ID constraint: Valid Bus:Device:Function
  // [15:8] = Bus, [7:3] = Device, [2:0] = Function
  constraint valid_requester_id_c {
    requester_id[7:3] inside {[0:31]};  // Device: 0-31
    requester_id[2:0] inside {[0:7]};   // Function: 0-7
    // Bus [15:8] can be any value 0-255
  }

  // Tag constraint: 8-bit tag for outstanding transactions
  constraint valid_tag_c {
    tag inside {[0:255]};  // Full 8-bit range
  }

  // First BE constraint: calculated based on address byte offset
  // address[1:0] determines starting byte position in first DW
  constraint valid_first_be_c {
    if (address[1:0] == 2'b00) {
      first_be == 4'b1111;  // Start at byte 0
    } else if (address[1:0] == 2'b01) {
      first_be == 4'b1110;  // Start at byte 1
    } else if (address[1:0] == 2'b10) {
      first_be == 4'b1100;  // Start at byte 2
    } else {  // address[1:0] == 2'b11
      first_be == 4'b1000;  // Start at byte 3
    }
  }

  // Last BE constraint: always enabled for all bytes
  constraint valid_last_be_c {
    if (length == 1) {
      // Single DW: last_be should be 0 per PCIe spec
      last_be == 4'b0000;
    } else {
      // Multi-DW: always enable all bytes in last DW
      last_be == 4'b1111;
    }
  }

  // Payload data size constraint: matches length for writes
  constraint payload_size_c {
    if (fmt[1] == 1'b1) {  // Has data payload
      payload_data.size() == length;
    } else {  // No data payload
      payload_data.size() == 0;
    }
  }


  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  
  function new(string name = "tl_tlp_seq_item");
    super.new(name);
  endfunction
  
  //------------------------------------------------------------------
  // Parse from tl_data_t stream
  //------------------------------------------------------------------
  
  function void parse_from_stream(tl_stream_t beat);
    data_beats.push_back(beat.data);
    
    // If this is the first beat (header), parse header fields
    if (data_beats.size() == 1) begin
      parse_header(beat.data);
    end
    else begin
      // Extract payload data
      for (int i = 0; i < 4; i++) begin
        payload_data.push_back(beat.data[i*32 +: 32]);
      end
    end
  endfunction
  
  //------------------------------------------------------------------
  // Parse TLP Header
  //------------------------------------------------------------------
  
  function void parse_header(bit [127:0] hdr);
    bit [31:0] dw0, dw1, dw2, dw3;
    
    dw0 = hdr[31:0];
    dw1 = hdr[63:32];
    dw2 = hdr[95:64];
    dw3 = hdr[127:96];
    
    // DW0: Format and Type (same for all TLP types)
    fmt      = dw0[7:5];
    pkt_type = dw0[4:0];
    tc       = dw0[14:12];
    length   = {dw0[17:16], dw0[31:24]};
    
    
    case ({fmt, pkt_type})
      8'b000_01010, 8'b010_01010: begin 
        parse_completion(hdr);
      end
      8'b000_00000, 8'b001_00000, 8'b010_00000, 8'b011_00000: begin
        parse_memory_rq(hdr);
      end
      8'b000_00100, 8'b010_00100: begin
        parse_config_rq(hdr);
      end 
    endcase
  endfunction


  function void parse_completion(bit[127:0] hdr);
    bit [31:0] dw0, dw1, dw2, dw3;
    
    
    dw0 = hdr[31:0];
    dw1 = hdr[63:32];
    dw2 = hdr[95:64];
    dw3 = hdr[127:96];


    fmt      = dw0[7:5];
    pkt_type = dw0[4:0];
    tc       = dw0[14:12];
    length   = {dw0[17:16], dw0[31:24]};

    completer_id = {dw1[7:0], dw1[15:8]};  // Byte-swapped
    status       = dw1[23:21];
    byte_count   = {dw1[19:16], dw1[31:24]};     // Byte-swapped
        
    // DW2: [31:16] = Requester ID, [15:8] = Tag, [7:0] = Lower Address
    requester_id = {dw2[7:0], dw2[15:8]};  // Byte-swapped
    tag          = dw2[23:16];
    lower_addr   = dw2[30:24];        // Only lower 7 bits used
        
        // first_be and last_be not used in completions
    first_be = 4'b0000;
    last_be  = 4'b0000;
        
    // DW3: First data DW for CplD (if has data)
    if (fmt[1]) begin  // CplD (with data)
      payload_data.push_back(dw3);
    end
  endfunction

  function void parse_memory_rq(bit [127:0] hdr);
    bit [31:0] dw0, dw1, dw2, dw3;
    
    dw0 = hdr[31:0];
    dw1 = hdr[63:32];
    dw2 = hdr[95:64];
    dw3 = hdr[127:96];

    fmt      = dw0[7:5];
    pkt_type = dw0[4:0];
    tc       = dw0[14:12];
    length   = {dw0[17:16], dw0[31:24]};


    requester_id = {dw1[7:0], dw1[15:8]};     // Byte-swapped
    tag          = dw1[23:16];
    last_be      = dw1[31:28];
    first_be     = dw1[27:24];
        
        // DW2 & DW3: Address (depends on 3DW vs 4DW format)
    if (fmt[0]) begin
      // 4DW header (64-bit address)
          // DW2 = Upper 32 bits, DW3 = Lower 32 bits
      address = {dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:24],   // Upper DW byte-swapped
                    dw3[7:0], dw3[15:8], dw3[23:16], dw3[31:26], 2'b00};  // Lower DW
    end else begin
      // 3DW header (32-bit address)
      // DW2 = Address [31:2]
      address = {32'h0, dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:26], 2'b00};
          
      // For 3DW with data (MWr), DW3 is first data DW
      if (fmt[1]) begin
        payload_data.push_back(dw3);
      end
    end
        
        // Clear completion fields for non-completion TLPs
    completer_id = 16'h0;
    status       = 3'b000;
    byte_count   = 12'h0;
  endfunction

  function parse_config_rq(bit [127:0] hdr);
    bit [31:0] dw0, dw1, dw2, dw3;
    dw0 = hdr[31:0];
    dw1 = hdr[63:32];
    dw2 = hdr[95:64];
    dw3 = hdr[127:96];

    fmt      = dw0[7:5];
    pkt_type = dw0[4:0];
    tc       = dw0[14:12];
    length   = {dw0[17:16], dw0[31:24]};


    requester_id = {dw1[7:0], dw1[15:8]};     // Byte-swapped
    tag          = dw1[23:16];
    last_be      = dw1[31:28];
    first_be     = dw1[27:24];
    // DW2: Configuration Space Address
    bus_number      = dw2[7:0];
    device_number   = dw2[15:11];
    function_number = dw2[10:8];
    register_number = {dw2[19:16], dw2[31:26]}; // Byte-swapped
  endfunction

  //------------------------------------------------------------------
  // Display functions
  //------------------------------------------------------------------
  
  function string get_type_str();
    case ({fmt,pkt_type})
      8'b000_00000, 8'b001_00000: return "MRd";
      8'b010_00000, 8'b011_00000: return "MWr";
      8'b000_00100: return "CfgRd0";
      8'b010_00100: return "CfgWr0";
      8'b000_01010: return "Cpl";
      8'b010_01011: return "CplD";
      default:  return $sformatf("Type_%02h", pkt_type);
    endcase
  endfunction
  
  function void do_print(uvm_printer printer);
    super.do_print(printer);
  endfunction
  

  function void build_tlp_beats (tl_tlp_seq_item txn, ref tl_stream_t beats[$]);
    bit [127:0] header;
    bit is_4dw_hdr;
    int num_data_dws;
    int beat_idx;
    bit has_data;
    tl_stream_t hdr_beat;
    
    beats.delete();
    
    // Determine header format
    is_4dw_hdr = (txn.fmt[0] == 1'b1);
    has_data = (txn.payload_data.size() > 0);
    
    // Build header (will include first data DW for 3DW with data)
    header = build_tlp_header(txn, is_4dw_hdr);
    
    // Create header beat
    hdr_beat.sop = 1'b1;
    hdr_beat.is_dllp = 1'b0;
    
    // For 3DW header with data, first data DW goes in header beat (DW3)
    if (!is_4dw_hdr && has_data) begin
      // Pack first data DW into header[127:96]
      hdr_beat.data[31:0]   = header[31:0];   // DW0
      hdr_beat.data[63:32]  = header[63:32];  // DW1
      hdr_beat.data[95:64]  = header[95:64];  // DW2 (address)
      hdr_beat.data[127:96] = txn.payload_data[0];  // DW3 = first data
      beat_idx = 1;  // Start from second data DW
      
      // Check if this is the only data DW
      hdr_beat.eop = (txn.payload_data.size() == 1);
    end
    else begin
      // 4DW header or no data: use header as-is
      hdr_beat.data = header;
      hdr_beat.eop = !has_data;  // EOP if no data payload
      beat_idx = 0;
    end
    
    beats.push_back(hdr_beat);
    
    // Add remaining data beats for writes or completions with data
    num_data_dws = txn.payload_data.size();
    
    if (beat_idx < num_data_dws) begin
      // Pack remaining payload DWs into 128-bit beats (4 DWs per beat)
      while (beat_idx < num_data_dws) begin
        tl_stream_t data_beat;
        data_beat.data = 128'h0;
        data_beat.sop = 1'b0;
        data_beat.is_dllp = 1'b0;
        
        // Pack up to 4 DWs into this beat
        for (int i = 0; i < 4 && beat_idx < num_data_dws; i++) begin
          data_beat.data[i*32 +: 32] = txn.payload_data[beat_idx];
          beat_idx++;
        end
        
        // Set EOP on last beat
        data_beat.eop = (beat_idx >= num_data_dws);
        
        beats.push_back(data_beat);
      end
    end
    
    `uvm_info(get_type_name(),
              $sformatf("Built %0d beats for TLP (3DW=%b, has_data=%b)", 
                       beats.size(), !is_4dw_hdr, has_data), UVM_HIGH)
    
  endfunction
  
  function bit [127:0] build_tlp_header(tl_tlp_seq_item txn, bit is_4dw_hdr);
    bit [31:0] dw0, dw1, dw2, dw3;
    
    
    // DW0: [7:5]=fmt, [4:0]=type, [14:12]=TC, [31:24,17:16]=length
    dw0[4:0]   = txn.pkt_type;
    dw0[7:5]   = txn.fmt;
    dw0[11:8] = 4'b0000;
    dw0[14:12] = txn.tc;
    dw0[15]    = 1'b0; // T9
    dw0[17:16] = txn.length[9:8];
    dw0[23:18] = 6'b000000;
    dw0[31:24] = txn.length[7:0];
    
    // DW1: Requester ID, Tag, Last BE, First BE
    dw1 = {txn.last_be, txn.first_be, 
           txn.tag, 
           txn.requester_id[7:0], txn.requester_id[15:8]};
    
    // DW2 & DW3: Address (format depends on 3DW vs 4DW)
    if (is_4dw_hdr) begin
      // 4DW header: DW2=upper 32 bits, DW3=lower 32 bits
      dw2 = {txn.address[39:32], txn.address[47:40], 
             txn.address[55:48], txn.address[63:56]};
      dw3 = {txn.address[7:2], 2'b00, 
             txn.address[15:8], txn.address[23:16], txn.address[31:24]};
    end
    else begin
      // 3DW header: DW2=address, DW3=reserved/first data DW
      dw2 = {txn.address[7:2], 2'b00,
             txn.address[15:8], txn.address[23:16], txn.address[31:24]};
      dw3 = 32'h0;  // Will be filled with first data DW if applicable
    end
    
    return {dw3, dw2, dw1, dw0};
  endfunction
  //------------------------------------------------------------------
// Comparison function - Validates TLP header against command
// Now includes first_be and last_be validation
//------------------------------------------------------------------

function bit compare_header(tl_user_seq_item cmd);
  bit match = 1;
  bit [3:0] expected_first_be;
  bit [3:0] expected_last_be;
  bit [1:0] start_offset;
  bit [1:0] end_offset;
  int total_bytes;
  bit [31:0] expected_cfg_address;
  
  // Calculate byte offsets
  start_offset = cmd.addr[1:0];
  total_bytes = cmd.length_dw * 4;  // Convert DWs to bytes
  end_offset = (start_offset + total_bytes - 1) & 2'b11;
  
  //------------------------------------------------------------------
  // Calculate expected first_be based on starting address offset
  //------------------------------------------------------------------
  case (start_offset)
    2'b00: expected_first_be = 4'b1111;  // Start at byte 0
    2'b01: expected_first_be = 4'b1110;  // Start at byte 1
    2'b10: expected_first_be = 4'b1100;  // Start at byte 2
    2'b11: expected_first_be = 4'b1000;  // Start at byte 3
  endcase
  
  //------------------------------------------------------------------
  // Calculate expected last_be based on ending address offset
  //------------------------------------------------------------------
  if (cmd.length_dw == 1) begin
    // Single DW transfer: last_be = 0 per PCIe spec
    expected_last_be = 4'b0000;
    
    // Adjust first_be for partial DW transfers
    case (start_offset)
      2'b00: begin
        case (total_bytes)
          1: expected_first_be = 4'b0001;
          2: expected_first_be = 4'b0011;
          3: expected_first_be = 4'b0111;
          default: expected_first_be = 4'b1111;
        endcase
      end
      2'b01: begin
        case (total_bytes)
          1: expected_first_be = 4'b0010;
          2: expected_first_be = 4'b0110;
          default: expected_first_be = 4'b1110;
        endcase
      end
      2'b10: begin
        case (total_bytes)
          1: expected_first_be = 4'b0100;
          default: expected_first_be = 4'b1100;
        endcase
      end
      2'b11: begin
        expected_first_be = 4'b1000;
      end
    endcase
  end
  else begin
    // Multi-DW transfer: calculate last_be from end offset
    case (end_offset)
      2'b00: expected_last_be = 4'b0001;  // Ends at byte 0
      2'b01: expected_last_be = 4'b0011;  // Ends at byte 1
      2'b10: expected_last_be = 4'b0111;  // Ends at byte 2
      2'b11: expected_last_be = 4'b1111;  // Ends at byte 3
    endcase
  end
  
  //------------------------------------------------------------------
  // Check transaction type and TLP format
  //------------------------------------------------------------------
  case (cmd.trans_type)
    tl_pkg::CMD_MEM: begin
      if (cmd.is_write) begin
        match &= (pkt_type == 5'b00010);  // Memory Write
        match &= (fmt[1] == 1'b1);        // Has data payload
      end
      else begin
        match &= (pkt_type == 5'b00000);  // Memory Read
        match &= (fmt[1] == 1'b0);        // No data payload
      end
      
      // Check address width: 3DW vs 4DW header
      if (cmd.addr[63:32] != 32'h0) begin
        match &= (fmt[0] == 1'b1);  // 4DW header
        match &= (address == {cmd.addr[63:2], 2'b00});
      end
      else begin
        match &= (fmt[0] == 1'b0);  // 3DW header
        match &= (address[31:0] == {cmd.addr[31:2], 2'b00});
      end
    end
    
    tl_pkg::CMD_CFG: begin
      if (cmd.is_write) begin
        match &= (pkt_type inside {5'b00100, 5'b00101});  // CfgWr0/CfgWr1
        match &= (fmt[1] == 1'b1);  // Has data
      end
      else begin
        match &= (pkt_type inside {5'b00100, 5'b00101});  // CfgRd0/CfgRd1
        match &= (fmt[1] == 1'b0);  // No data
      end
      
      // Config address = {bus[7:0], device[4:0], function[2:0], reg[9:2], 2'b00}
      expected_cfg_address = {cmd.bus, cmd.device, cmd.function_num, cmd.reg_num[9:2], 2'b00};
      match &= (address[31:0] == expected_cfg_address);
    end
    
    default: begin
      `uvm_error("TLP_CMP", $sformatf("Unknown trans_type: %s", cmd.trans_type.name()))
      match = 0;
    end
  endcase
  
  //------------------------------------------------------------------
  // Check length (in DWs)
  //------------------------------------------------------------------
  match &= (length == cmd.length_dw);
  
  //------------------------------------------------------------------
  // Check Byte Enables
  //------------------------------------------------------------------
  match &= (first_be == expected_first_be);
  match &= (last_be == expected_last_be);
  
  //------------------------------------------------------------------
  // Debug output on mismatch
  //------------------------------------------------------------------
  if (!match) begin
    `uvm_info("TLP_CMP", $sformatf({
      "Header Mismatch:\n",
      "  Type: %s, %s\n",
      "  address: 0x%0h (offset %0d)\n",
      "  Length: %0d DW (%0d bytes)\n",
      "  Expected BE: first=0x%h, last=0x%h\n",
      "  Got BE:      first=0x%h, last=0x%h\n",
      "  TLP Type: 0x%h, Fmt: 0x%h"},
      cmd.trans_type.name(),
      cmd.is_write ? "Write" : "Read",
      cmd.addr, start_offset,
      cmd.length_dw, total_bytes,
      expected_first_be, expected_last_be,
      first_be, last_be,
      pkt_type, fmt), UVM_LOW)
  end
  
  return match;
endfunction : compare_header


endclass : tl_tlp_seq_item

`endif // TL_TLP_SEQ_ITEM_SV