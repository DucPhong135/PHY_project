`ifndef TL_TLP_SEQ_ITEM_SV
`define TL_TLP_SEQ_ITEM_SV


class tl_tlp_seq_item extends uvm_sequence_item;
  
  //------------------------------------------------------------------
  // TLP Packet Fields (captured from tl_tx_o / tl_rx_i)
  //------------------------------------------------------------------
  static int item_count = 0;
  int item_id;
  // Raw TLP data stream
  rand bit [127:0] data_beats[$];  // Queue of 128-bit beats
  rand bit         sop;             // Start of Packet
  rand bit         eop;             // End of Packet
  
  // Parsed TLP Header Fields
  bit [2:0]  fmt;                   // Format (3DW/4DW, with/without data)
  bit [4:0]  pkt_type;              // TLP type (MRd, MWr, CfgRd, CplD, etc.)
  bit [2:0]  tc;                    // Traffic Class
  bit [9:0]  length;                // Length in DWs
  bit [15:0] requester_id;          // Requester ID (Bus:Dev:Func)
  bit [7:0]  tag;                   // Transaction tag
  bit [63:0] address;               // Address (32-bit or 64-bit)
  bit [3:0]  first_be;              // First DW Byte Enable
  bit [3:0]  last_be;               // Last DW Byte Enable
  
  // For Completions
  bit [15:0] completer_id;          // Completer ID
  bit [2:0]  status;                // Completion status
  bit [11:0] byte_count;            // Byte count
  
  // Payload data
  bit [31:0] payload_data[$];       // Queue of payload DWs
  
  //------------------------------------------------------------------
  // UVM Automation
  //------------------------------------------------------------------
  
  `uvm_object_utils_begin(tl_tlp_seq_item)
    `uvm_field_int(item_id,      UVM_ALL_ON | UVM_DEC)
    `uvm_field_queue_int(data_beats, UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(sop,           UVM_ALL_ON)
    `uvm_field_int(eop,           UVM_ALL_ON)
    `uvm_field_int(fmt,           UVM_ALL_ON | UVM_BIN)
    `uvm_field_int(pkt_type,      UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(length,        UVM_ALL_ON | UVM_DEC)
    `uvm_field_int(requester_id,  UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(tag,           UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(address,       UVM_ALL_ON | UVM_HEX)
    `uvm_field_int(first_be,      UVM_ALL_ON | UVM_BIN)
    `uvm_field_queue_int(payload_data, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  //------------------------------------------------------------------
  // Constructor
  //------------------------------------------------------------------
  
  function new(string name = "tl_tlp_seq_item");
    super.new(name);
    item_count++;
    item_id = item_count;
  endfunction
  
  //------------------------------------------------------------------
  // Parse from tl_data_t stream
  //------------------------------------------------------------------
  
  function void parse_from_stream(tl_pkg::tl_stream_t beat);
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
    
    // DW0: Format and Type
    fmt      = dw0[7:5];
    pkt_type = dw0[4:0];
    tc       = dw0[14:12];
    length   = {dw0[17:16], dw0[31:24]};
    
    // DW1: Requester ID, Tag, Byte Enables
    requester_id = {dw1[7:0], dw1[15:8]};
    tag          = dw1[23:16];
    last_be      = dw1[31:28];
    first_be     = dw1[27:24];
    
    // DW2 & DW3: Address (depends on 3DW vs 4DW format)
    if (fmt[0]) begin
      // 4DW header (64-bit address)
      address = {dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:24], dw3[7:0], dw3[15:8], dw3[23:16], dw3[31:26], 2'b00};
    end
    else begin
      // 3DW header (32-bit address)
      address = {32'h0, dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:26], 2'b00};
      
      // For 3DW with data, DW3 is first data DW
      if (fmt[1]) begin  // Has data
        payload_data.push_back(dw3);
      end
    end

    
    // For Completions, parse completion-specific fields
    if (pkt_type inside {5'b01010, 5'b01011}) begin  // Cpl, CplD
      completer_id = dw1[31:16];
      status       = dw1[15:13];
      byte_count   = dw1[11:0];
    end
  endfunction
  
  //------------------------------------------------------------------
  // Display functions
  //------------------------------------------------------------------
  
  function string get_type_str();
    case (pkt_type)
      5'b00000: return "MRd";
      5'b00001: return "MRd (locked)";
      5'b00010: return "MWr";
      5'b00011: return "MWr (locked)";
      5'b00100: return "IORd";
      5'b00110: return "IOWr";
      5'b01010: return "Cpl";
      5'b01011: return "CplD";
      default:  return $sformatf("Type_%02h", pkt_type);
    endcase
  endfunction

  function int get_pkt_num();
    return item_id;
  endfunction
  
  function void do_print(uvm_printer printer);
    super.do_print(printer);
    printer.print_field("Item ID", item_id, 32, UVM_DEC);
    printer.print_field("Total Items Created", item_count, 32, UVM_DEC);
    printer.print_string("TLP Type", get_type_str());
    printer.print_field("Format", fmt, 3, UVM_BIN);
    printer.print_field("Length (DW)", length, 10, UVM_DEC);
    printer.print_field("Address", address, 64, UVM_HEX);
    printer.print_field("Tag", tag, 8, UVM_HEX);
    printer.print_field("Requester ID", requester_id, 16, UVM_HEX);
    printer.print_field("Payload DWs", payload_data.size(), 32, UVM_DEC);
  endfunction
  
  //------------------------------------------------------------------
  // Comparison functions
  //------------------------------------------------------------------
  
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
  bit [31:0] expected_cfg_addr;
  
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
      expected_cfg_addr = {cmd.bus, cmd.device, cmd.function_num, cmd.reg_num[9:2], 2'b00};
      match &= (address[31:0] == expected_cfg_addr);
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
      "  Addr: 0x%0h (offset %0d)\n",
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