`ifndef TL_TLP_SEQ_ITEM_SV
`define TL_TLP_SEQ_ITEM_SV


class tl_tlp_seq_item extends uvm_sequence_item;
  
  bit [127:0] data_beats[$];
  
  // Parsed TLP Header Fields
  rand bit [2:0]  fmt;                   
  rand bit [4:0]  pkt_type;             
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
  bit [31:0] config_data;

  // Payload data
  rand bit [31:0] payload_data[$];
  
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
    `uvm_field_int(config_data,   UVM_ALL_ON | UVM_HEX)
    `uvm_field_queue_int(payload_data, UVM_ALL_ON | UVM_HEX)
  `uvm_object_utils_end
  
  //------------------------------------------------------------------
  // Constraints
  //------------------------------------------------------------------
  
  constraint valid_length_c {
    length inside {[1:1024]};
  }

  constraint valid_pkt_type_c {
    pkt_type inside {
      5'b00000,  
      5'b01010  
    };
  }

  constraint fmt_pkt_type_consistency_c {
    fmt inside {3'b000, 3'b001, 3'b010, 3'b011};
  }



  constraint valid_requester_id_c {
    requester_id[7:3] inside {[0:31]};  
    requester_id[2:0] inside {[0:7]};   
  }

  constraint valid_tag_c {
    tag inside {[0:255]};
  }


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
    if (fmt[1] == 1'b1) {
      payload_data.size() == length;
    } else {
      payload_data.size() == 0;
    }
  }

  
  function new(string name = "tl_tlp_seq_item");
    super.new(name);
  endfunction
  

  
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

    completer_id = {dw1[7:0], dw1[15:8]};  
    status       = dw1[23:21];
    byte_count   = {dw1[19:16], dw1[31:24]};     
        
    requester_id = {dw2[7:0], dw2[15:8]};  
    tag          = dw2[23:16];
    lower_addr   = dw2[30:24];       
        
    first_be = 4'b0000;
    last_be  = 4'b0000;
        
    if (fmt[1]) begin
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


    requester_id = {dw1[7:0], dw1[15:8]};     
    tag          = dw1[23:16];
    last_be      = dw1[31:28];
    first_be     = dw1[27:24];
        
    if (fmt[0]) begin
      address = {dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:24],   
                    dw3[7:0], dw3[15:8], dw3[23:16], dw3[31:26], 2'b00};  
    end else begin
      address = {32'h0, dw2[7:0], dw2[15:8], dw2[23:16], dw2[31:26], 2'b00};
          
      if (fmt[1]) begin
        payload_data.push_back(dw3);
      end
    end
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


    requester_id = {dw1[7:0], dw1[15:8]};     
    tag          = dw1[23:16];
    last_be      = dw1[31:28];
    first_be     = dw1[27:24];

    bus_number      = dw2[7:0];
    device_number   = dw2[15:11];
    function_number = dw2[10:8];
    register_number = {dw2[19:16], dw2[31:26]}; 

    if (fmt[1]) begin
      config_data = dw3;
    end else begin
      config_data = 32'h0;
    end
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
    
    is_4dw_hdr = (txn.fmt[0] == 1'b1);
    has_data = (txn.payload_data.size() > 0);
    
    header = build_tlp_header(txn, is_4dw_hdr);
    
    // Create header beat
    hdr_beat.sop = 1'b1;
    hdr_beat.is_dllp = 1'b0;
    
    // For 3DW header with data, first data DW goes in header beat (DW3)
    if (!is_4dw_hdr && has_data) begin
      hdr_beat.data[31:0]   = header[31:0];
      hdr_beat.data[63:32]  = header[63:32];
      hdr_beat.data[95:64]  = header[95:64];
      hdr_beat.data[127:96] = txn.payload_data[0];
      beat_idx = 1;
      
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
    
    num_data_dws = txn.payload_data.size();
    
    if (beat_idx < num_data_dws) begin
      while (beat_idx < num_data_dws) begin
        tl_stream_t data_beat;
        data_beat.data = 128'h0;
        data_beat.sop = 1'b0;
        data_beat.is_dllp = 1'b0;
        
        for (int i = 0; i < 4 && beat_idx < num_data_dws; i++) begin
          data_beat.data[i*32 +: 32] = txn.payload_data[beat_idx];
          beat_idx++;
        end
        
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
    
    
    if(txn.pkt_type == 5'b01010) begin
      dw0[4:0]   = txn.pkt_type;
      dw0[7:5]   = txn.fmt;
      dw0[11:8] = 4'b0000;
      dw0[14:12] = txn.tc;
      dw0[15]    = 1'b0;
      dw0[23:18] = 6'b000000;
      dw0[17:16] = txn.length[9:8];
      dw0[31:24] = txn.length[7:0];
      
      dw1[7:0] = txn.completer_id[15:8];
      dw1[15:8] = txn.completer_id[7:0];
      dw1[19:16] = txn.byte_count[11:8];
      dw1[20] = 1'b0;
      dw1[23:21] = txn.status;
      dw1[31:24] = txn.byte_count[7:0];
      
      dw2[7:0] = txn.requester_id[15:8];
      dw2[15:8] = txn.requester_id[7:0];
      dw2[23:16] = txn.tag;
      dw2[30:24] = txn.lower_addr[6:0];
      dw2[31] = 1'b0;
      dw3 = 32'h0;  
    end
    else begin
      dw0[4:0]   = txn.pkt_type;
      dw0[7:5]   = txn.fmt;
      dw0[11:8] = 4'b0000;
      dw0[14:12] = txn.tc;
      dw0[15]    = 1'b0;
      dw0[17:16] = txn.length[9:8];
      dw0[23:18] = 6'b000000;
      dw0[31:24] = txn.length[7:0];
      
      dw1 = {txn.last_be, txn.first_be, 
            txn.tag, 
            txn.requester_id[7:0], txn.requester_id[15:8]};
      
      if (is_4dw_hdr) begin
        dw2 = {txn.address[39:32], txn.address[47:40], 
              txn.address[55:48], txn.address[63:56]};
        dw3 = {txn.address[7:2], 2'b00, 
              txn.address[15:8], txn.address[23:16], txn.address[31:24]};
      end
      else begin
        dw2 = {txn.address[7:2], 2'b00,
              txn.address[15:8], txn.address[23:16], txn.address[31:24]};
        dw3 = 32'h0;  // Will be filled with first data DW if applicable
      end
    end
    
    return {dw3, dw2, dw1, dw0};
  endfunction

  function need_cpl();
    return ((pkt_type == 5'b00000) && (fmt == 3'b000 || fmt ==3'b001)) ||
           ((pkt_type == 5'b00100));
  endfunction



endclass : tl_tlp_seq_item

`endif // TL_TLP_SEQ_ITEM_SV