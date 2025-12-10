`ifndef TL_DLL_DRIVER_SV
`define TL_DLL_DRIVER_SV

class tl_dll_driver extends uvm_driver #(tl_tlp_seq_item);

  `uvm_component_utils(tl_dll_driver)

  // Virtual interface
  virtual tl_dll_if vif;

  // Constructor
  function new(string name = "tl_dll_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  // Build phase: get virtual interface
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual tl_dll_if)::get(this, "", "dll_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.dll_vif", get_full_name()))
    end
  endfunction : build_phase

  // Main run phase
  task run_phase(uvm_phase phase);
    tl_tlp_seq_item txn;
    tl_stream_t beats[$];
    
    // Initialize interface
    vif.init_signals();
    
    // Wait for reset
    @(negedge vif.rst_n);
    @(posedge vif.rst_n);
    
    forever begin
      // Get next transaction from sequencer
      seq_item_port.get_next_item(txn);
      `uvm_info("DLL_DRV", "Received new TLP transaction from sequencer", UVM_LOW);
      txn.print();

      // Build TLP beats from transaction
      txn.build_tlp_beats(txn, beats);
      
      // Drive TLP onto RX interface
      vif.drive_tlp_packet(beats);
      
      // Indicate item is done
      seq_item_port.item_done();
    end
  endtask : run_phase
  
  // //================================================================
  // // Build TLP Beats from Sequence Item
  // //================================================================
  // task build_tlp_beats(tl_tlp_seq_item txn, output tl_stream_t beats[$]);
  //   bit [127:0] header;
  //   bit is_4dw_hdr;
  //   int num_data_dws;
  //   int beat_idx;
  //   bit has_data;
  //   tl_stream_t hdr_beat;
    
  //   beats.delete();
    
  //   // Determine header format
  //   is_4dw_hdr = (txn.fmt[0] == 1'b1);
  //   has_data = (txn.payload_data.size() > 0);
    
  //   // Build header (will include first data DW for 3DW with data)
  //   header = build_tlp_header(txn, is_4dw_hdr);
    
  //   // Create header beat
  //   hdr_beat.sop = 1'b1;
  //   hdr_beat.is_dllp = 1'b0;
    
  //   // For 3DW header with data, first data DW goes in header beat (DW3)
  //   if (!is_4dw_hdr && has_data) begin
  //     // Pack first data DW into header[127:96]
  //     hdr_beat.data[31:0]   = header[31:0];   // DW0
  //     hdr_beat.data[63:32]  = header[63:32];  // DW1
  //     hdr_beat.data[95:64]  = header[95:64];  // DW2 (address)
  //     hdr_beat.data[127:96] = txn.payload_data[0];  // DW3 = first data
  //     beat_idx = 1;  // Start from second data DW
      
  //     // Check if this is the only data DW
  //     hdr_beat.eop = (txn.payload_data.size() == 1);
  //   end
  //   else begin
  //     // 4DW header or no data: use header as-is
  //     hdr_beat.data = header;
  //     hdr_beat.eop = !has_data;  // EOP if no data payload
  //     beat_idx = 0;
  //   end
    
  //   beats.push_back(hdr_beat);
    
  //   // Add remaining data beats for writes or completions with data
  //   num_data_dws = txn.payload_data.size();
    
  //   if (beat_idx < num_data_dws) begin
  //     // Pack remaining payload DWs into 128-bit beats (4 DWs per beat)
  //     while (beat_idx < num_data_dws) begin
  //       tl_stream_t data_beat;
  //       data_beat.data = 128'h0;
  //       data_beat.sop = 1'b0;
  //       data_beat.is_dllp = 1'b0;
        
  //       // Pack up to 4 DWs into this beat
  //       for (int i = 0; i < 4 && beat_idx < num_data_dws; i++) begin
  //         data_beat.data[i*32 +: 32] = txn.payload_data[beat_idx];
  //         beat_idx++;
  //       end
        
  //       // Set EOP on last beat
  //       data_beat.eop = (beat_idx >= num_data_dws);
        
  //       beats.push_back(data_beat);
  //     end
  //   end
    
  //   `uvm_info(get_type_name(),
  //             $sformatf("Built %0d beats for TLP (3DW=%b, has_data=%b)", 
  //                      beats.size(), !is_4dw_hdr, has_data), UVM_HIGH)
    
  // endtask
  
  //================================================================
  // Build TLP Header (128 bits)
  //================================================================
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
  

endclass : tl_dll_driver

`endif // TL_DLL_DRIVER_SV