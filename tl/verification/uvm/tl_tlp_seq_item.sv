`ifndef TL_TLP_SEQ_ITEM_SV
`define TL_TLP_SEQ_ITEM_SV


class tl_tlp_seq_item extends uvm_sequence_item;
  
  //------------------------------------------------------------------
  // TLP Packet Fields (captured from tl_tx_o / tl_rx_i)
  //------------------------------------------------------------------
  
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
  endfunction
  
  //------------------------------------------------------------------
  // Parse from tl_data_t stream
  //------------------------------------------------------------------
  
  function void parse_from_stream(tl_pkg::tl_data_t beat);
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
    fmt      = dw0[31:29];
    pkt_type = dw0[28:24];
    tc       = dw0[22:20];
    length   = dw0[9:0];
    
    // DW1: Requester ID, Tag, Byte Enables
    requester_id = dw1[31:16];
    tag          = dw1[15:8];
    last_be      = dw1[7:4];
    first_be     = dw1[3:0];
    
    // DW2 & DW3: Address (depends on 3DW vs 4DW format)
    if (fmt[0]) begin
      // 4DW header (64-bit address)
      address = {dw2, dw3[31:2], 2'b00};
    end
    else begin
      // 3DW header (32-bit address)
      address = {32'h0, dw2[31:2], 2'b00};
      
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
  
  function void do_print(uvm_printer printer);
    super.do_print(printer);
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
  
  function bit compare_header(tl_cmd_seq_item cmd);
    bit match = 1;
    
    // Check transaction type
    case (cmd.trans_type)
      tl_pkg::CMD_MEM: begin
        if (cmd.is_write) begin
          match &= (pkt_type == 5'b00010);  // MWr
        end
        else begin
          match &= (pkt_type == 5'b00000);  // MRd
        end
      end
      
      tl_pkg::CMD_CFG: begin
        if (cmd.is_write) begin
          match &= (pkt_type inside {5'b01011, 5'b01010});  // CfgWr0/1
        end
        else begin
          match &= (pkt_type inside {5'b00100, 5'b00101});  // CfgRd0/1
        end
      end
    endcase
    
    // Check length
    match &= (length == cmd.length_dw);
    
    // Check address
    if (cmd.trans_type == tl_pkg::CMD_MEM) begin
      match &= (address[63:2] == cmd.addr[63:2]);  // Ignore byte offset
    end
    
    // Check byte enables
    match &= (first_be == cmd.first_be);
    
    return match;
  endfunction

endclass : tl_tlp_seq_item

`endif // TL_TLP_SEQ_ITEM_SV