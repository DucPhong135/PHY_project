`ifndef CPL_SEQUENCE_SV
`define CPL_SEQUENCE_SV

class cpl_sequence extends uvm_sequence#(tl_tlp_seq_item);

  `uvm_object_utils(cpl_sequence)

  // ──────────────────────────────────────────────────────────────
  // Configuration
  // ──────────────────────────────────────────────────────────────
  


  // Batch settings
  int batch_size = 5;                    // Number of requests before processing
  int batch_timeout_cycles = 100;       // Timeout for incomplete batches
  bit enable_timeout = 1;                // Enable timeout feature
  
  // Shuffle settings
  typedef enum {
    SHUFFLE_NONE,       // In-order (FIFO)
    SHUFFLE_RANDOM,     // Completely random
    SHUFFLE_INTERLEAVE  // Alternate first/last
  } shuffle_mode_e;
  
  shuffle_mode_e shuffle_mode = SHUFFLE_NONE;  // Default: no shuffling
  
  // Completion settings
  bit [2:0]  default_status = 3'b000;    // SC (Successful Completion)
  
  // Error injection
  bit enable_error_injection = 0;
  int error_rate = 0;                    // Percentage (0-100)

  function new(string name = "cpl_sequence");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  task body();
    tl_dll_sequencer dll_sqr;
    tl_tlp_seq_item request_batch[$];
    tl_tlp_seq_item request;
    tl_tlp_seq_item completion;
    int delay;
    
    // Cast to get reference to THE SAME sequencer passed via start()
    if (!$cast(dll_sqr, m_sequencer)) begin
        `uvm_fatal(get_type_name(), "Cast failed")
    end
    

    `uvm_info(get_type_name(), 
          $sformatf("Reactive completion sequence started:\n  batch_size=%0d\n  shuffle_mode=%s\n  timeout=%0d cycles", 
                   batch_size, shuffle_mode.name(), batch_timeout_cycles), 
          UVM_LOW)
    
    forever begin
      
      // ─────────────────────────────────────────────────────────
      // PHASE 1: Collect batch of requests
      // ─────────────────────────────────────────────────────────
      request_batch.delete();
      
      if (enable_timeout) begin
        collect_batch_with_timeout(dll_sqr, request_batch);
      end else begin
        collect_batch_no_timeout(dll_sqr, request_batch);
      end
      
      if (request_batch.size() == 0) begin
        `uvm_info(get_type_name(), "No requests collected, stop simulation", UVM_LOW)
        break;
      end
      
      `uvm_info(get_type_name(), 
                $sformatf("Batch collected: %0d requests %s", 
                         request_batch.size(),
                         (request_batch.size() < batch_size) ? "(partial - timeout)" : "(full)"), 
                UVM_MEDIUM)
      
      // ─────────────────────────────────────────────────────────
      // PHASE 2: Reorder batch based on shuffle mode
      // ─────────────────────────────────────────────────────────
      reorder_batch(request_batch);
      
      // ─────────────────────────────────────────────────────────
      // PHASE 3: Send completions
      // 
      foreach (request_batch[i]) begin
        request = request_batch[i];
        
        if(request == null) begin
          `uvm_warning(get_type_name(), $sformatf("Request %0d is NULL, skipping", i))
        end
        
        completion = build_completion(request);
        `uvm_info(get_type_name(), 
                  $sformatf("Built completion for request tag=%0d: ",completion.tag), UVM_LOW)
        completion.print();
        // Build and send completion
        start_item(completion);
        finish_item(completion);
        
        `uvm_info(get_type_name(), 
                  $sformatf("Sent completion [%0d/%0d]: tag=%0d, status=%s", 
                           i+1, request_batch.size(), completion.tag,
                           (completion.status == 3'b000) ? "SC" : "ERROR"), 
                  UVM_MEDIUM)
      end
      
      `uvm_info(get_type_name(), 
                $sformatf("Batch complete: sent %0d completions", request_batch.size()), 
                UVM_LOW)
    end
  endtask

  // ──────────────────────────────────────────────────────────────
  // Collect batch WITH timeout
  // ──────────────────────────────────────────────────────────────
  task collect_batch_with_timeout(tl_dll_sequencer sqr, ref tl_tlp_seq_item batch[$]);
    tl_tlp_seq_item req;
    bit timeout_occurred = 0;
    
    fork
      begin : collection_thread
        while (batch.size() < batch_size) begin
          sqr.get_request(req);
          batch.push_back(req);
          
          `uvm_info(get_type_name(), 
                    $sformatf("Collected [%0d/%0d]: tag=%0d, addr=0x%h", 
                             batch.size(), batch_size, req.tag, req.address), 
                    UVM_LOW)
          @(posedge sqr.vif.clk);
        end
      end
      
      begin : timeout_thread
        repeat(batch_timeout_cycles) @(sqr.vif.clk);
        if (batch.size() > 0) begin
          timeout_occurred = 1;
          `uvm_info(get_type_name(), 
                    $sformatf("Timeout after %0d cycles with %0d/%0d requests", 
                             batch_timeout_cycles, batch.size(), batch_size), 
                    UVM_MEDIUM)
        end
      end
    join_any
    
    disable fork;
  endtask

  // ──────────────────────────────────────────────────────────────
  // Collect batch WITHOUT timeout (wait for full batch)
  // ──────────────────────────────────────────────────────────────
  task collect_batch_no_timeout(tl_dll_sequencer sqr, ref tl_tlp_seq_item batch[$]);
    tl_tlp_seq_item req;
    
    while (batch.size() < batch_size) begin
      sqr.get_request(req);
      batch.push_back(req);
      
      `uvm_info(get_type_name(), 
                $sformatf("Collected [%0d/%0d]: tag=%0d", 
                         batch.size(), batch_size, req.tag), 
                UVM_HIGH)
    end
  endtask

  // ──────────────────────────────────────────────────────────────
  // Reorder batch based on shuffle mode
  // ──────────────────────────────────────────────────────────────
  function void reorder_batch(ref tl_tlp_seq_item batch[$]);
    tl_tlp_seq_item temp_batch[$];
    
    case (shuffle_mode)
      
      SHUFFLE_NONE: begin
        // Keep original order (FIFO)
        `uvm_info(get_type_name(), "Order: IN-ORDER (FIFO)", UVM_HIGH)
      end
      
      SHUFFLE_RANDOM: begin
        batch.shuffle();
        `uvm_info(get_type_name(), "Order: RANDOM shuffle", UVM_HIGH)
      end
    
      
      SHUFFLE_INTERLEAVE: begin
        temp_batch = batch;
        batch.delete();
        
        while (temp_batch.size() > 0) begin
          // Take from front
          if (temp_batch.size() > 0) begin
            batch.push_back(temp_batch.pop_front());
          end
          // Take from back
          if (temp_batch.size() > 0) begin
            batch.push_back(temp_batch.pop_back());
          end
        end
        `uvm_info(get_type_name(), "Order: INTERLEAVE pattern", UVM_HIGH)
      end
      
      default: begin
        `uvm_warning(get_type_name(), "Unknown shuffle mode, using FIFO")
      end
      
    endcase
    
    // Log final order
    if (uvm_report_enabled(UVM_HIGH)) begin
      foreach (batch[i]) begin
        `uvm_info(get_type_name(), 
                  $sformatf("  Final order[%0d]: tag=%0d", i, batch[i].tag), 
                  UVM_HIGH)
      end
    end
  endfunction

  // ──────────────────────────────────────────────────────────────
  // Build completion TLP from request
  // ──────────────────────────────────────────────────────────────
  function tl_tlp_seq_item build_completion(tl_tlp_seq_item req);
    tl_tlp_seq_item cpl;
    int byte_count;
    bit [2:0] status;
    
    cpl = tl_tlp_seq_item::type_id::create("cpl");
    
    // Calculate byte count based on byte enables
    if (req.length == 1) begin
      byte_count = $countones(req.first_be);
    end else begin
      byte_count = $countones(req.first_be) + 
                   (req.length - 2) * 4 + 
                   $countones(req.last_be);
    end
    
    // Determine status (with optional error injection)
    if (enable_error_injection && ($urandom_range(100) < error_rate)) begin
      // Inject random error status
      case ($urandom_range(2))
        0: status = 3'b001;  // UR (Unsupported Request)
        1: status = 3'b010;  // CRS (Configuration Request Retry Status)
        2: status = 3'b100;  // CA (Completer Abort)
      endcase
      `uvm_info(get_type_name(), 
                $sformatf("Injecting error status: %0d for tag=%0d", status, req.tag), 
                UVM_MEDIUM)
    end else begin
      status = default_status;
    end
    
    // Build completion header
    if((req.fmt == 3'b000 || req.fmt == 3'b001) && req.pkt_type == 5'b00000) begin
      // 3DW header
      cpl.fmt = 3'b010;              
      cpl.pkt_type = 5'b01010;      
      cpl.length = (byte_count + 3) / 4;
    end else if((req.fmt == 3'b000) && req.pkt_type == 5'b00100) begin
        cpl.fmt = 3'b010;
        cpl.pkt_type = 5'b01010;
        cpl.length = 10'd1;
    end else if((req.fmt == 3'b010) && req.pkt_type == 5'b00100) begin
        cpl.fmt = 3'b000;
        cpl.pkt_type = 5'b01010;
    end else begin
        `uvm_info(get_type_name(),
                  $sformatf("Request fmt/type not supported for completion generation: fmt=%0b, type=%0b. Using default CplD 3DW",
                           req.fmt, req.pkt_type),
                  UVM_MEDIUM
                )
    end
    cpl.tc = req.tc;
    if(req.pkt_type == 5'b00100) begin
        cpl.completer_id = {req.bus_number, req.device_number, req.function_number};
    end else begin
        cpl.completer_id = $urandom_range(65535, 1000); // Random completer ID
    end
    cpl.status = status;
    cpl.byte_count = byte_count;
    cpl.requester_id = req.requester_id;
    cpl.tag = req.tag;
    cpl.lower_addr = req.address[6:0];
    

    // Generate random payload data
    cpl.payload_data.delete();
    if(cpl.fmt[1] == 1'b1) begin
        // CplD with data - account for byte enables
        for (int dw = 0; dw < cpl.length; dw++) begin
            bit [3:0] be;
            bit [31:0] data;
            
            // Determine byte enable for this DW
            if (cpl.length == 1) begin
                // Single DW: only first_be applies
                be = req.first_be;
            end else if (dw == 0) begin
                // First DW
                be = req.first_be;
            end else if (dw == cpl.length - 1) begin
                // Last DW
                be = req.last_be;
            end else begin
                // Middle DWs: all bytes enabled
                be = 4'b1111;
            end
            
            // Generate data with only enabled bytes having valid data
            // Disabled bytes are set to 0 (or could be random - doesn't matter)
            data = 32'h0;
            for (int byte_idx = 0; byte_idx < 4; byte_idx++) begin
                if (be[byte_idx]) begin
                    data[byte_idx*8 +: 8] = $urandom_range(255, 0);
                end else begin
                    data[byte_idx*8 +: 8] = 8'h00;  // Or $urandom() if you prefer
                end
            end
            
            cpl.payload_data.push_back(data);
        end
    end
    
    return cpl;
  endfunction

endclass : cpl_sequence

`endif // CPL_SEQUENCE_SV