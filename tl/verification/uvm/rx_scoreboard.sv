

class rx_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(rx_scoreboard)
    // Queues to hold expected transactions
  tl_tlp_seq_item expected_rx_tlp_write_queue[$];
  mem_sequence_item actual_mem_write_queue[$];

  tl_tlp_seq_item expected_rx_tlp_read_queue[$];
  tl_tlp_seq_item actual_tx_tlp_read_queue[$];
    mem_sequence_item expected_mem_read_queue[$];

  // Queues to hold mismatched transactions for reporting
  tl_tlp_seq_item write_mismatch_dll_rx_tlp_queue[$];
  mem_sequence_item write_mismatch_mem_queue[$];
  tl_tlp_seq_item read_mismatch_dll_rx_tlp_queue[$];
  mem_sequence_item read_mismatch_mem_queue[$];
  tl_tlp_seq_item read_mismatch_dll_tx_tlp_queue[$];

  int unsigned match_read_count = 0;
  int unsigned match_write_count = 0;
  int unsigned mismatch_read_count = 0;
  int unsigned mismatch_write_count = 0;


  `uvm_analysis_imp_decl(_tx_dll)
  uvm_analysis_imp_tx_dll #(tl_tlp_seq_item, rx_scoreboard) tx_dll_in;

  function void write_tx_dll(tl_tlp_seq_item tx_tlp);
    tl_tlp_seq_item actual_tlp;
    `uvm_info("RX_SCOREBOARD", $sformatf("Received TX TLP in RX Scoreboard:"), UVM_LOW);
    tx_tlp.print();
    $cast(actual_tlp, tx_tlp.clone());
    if(tx_tlp.pkt_type == 5'b01010) begin
        actual_tx_tlp_read_queue.push_back(actual_tlp);
    end
    else begin
        `uvm_warning("RX_SCOREBOARD", "Received non-completion TLP in tx_dll_in")
    end
  endfunction : write_tx_dll


  `uvm_analysis_imp_decl(_mem)
  uvm_analysis_imp_mem #(mem_sequence_item, rx_scoreboard) mem_in;

  function void write_mem(mem_sequence_item mem_tlp);
    mem_sequence_item expected_mem;
    `uvm_info("RX_SCOREBOARD", $sformatf("Received Memory TLP in RX Scoreboard:"), UVM_LOW);
    mem_tlp.print();
    $cast(expected_mem, mem_tlp.clone());
    if(!mem_tlp.is_write) begin
        expected_mem_read_queue.push_back(expected_mem);
    end else if (mem_tlp.is_write) begin
        actual_mem_write_queue.push_back(expected_mem);
    end
  endfunction : write_mem


  `uvm_analysis_imp_decl(_rx_dll)
  uvm_analysis_imp_rx_dll #(tl_tlp_seq_item, rx_scoreboard) rx_dll_in;

  function void write_rx_dll(tl_tlp_seq_item rx_tlp);
    tl_tlp_seq_item expected_tlp;
    mem_sequence_item expected_mem;
    $cast(expected_tlp, rx_tlp.clone());
    `uvm_info("RX_SCOREBOARD", $sformatf("Received RX TLP in RX Scoreboard:"), UVM_LOW);
    rx_tlp.print();
    if(rx_tlp.pkt_type == 5'b00000 && (rx_tlp.fmt == 3'b001 || rx_tlp.fmt == 3'b000)) begin
        expected_rx_tlp_read_queue.push_back(expected_tlp);
    end else if(rx_tlp.pkt_type == 5'b00000 && (rx_tlp.fmt == 3'b011 || rx_tlp.fmt == 3'b010)) begin
        expected_rx_tlp_write_queue.push_back(expected_tlp);
    end else begin
        `uvm_warning("RX_SCOREBOARD", "Received non-read/write TLP in rx_dll_in")
    end
  endfunction : write_rx_dll


    function new(string name = "rx_scoreboard", uvm_component parent = null);
        super.new(name, parent);
        mem_in = new("mem_in", this);
        rx_dll_in = new("rx_dll_in", this);
        tx_dll_in = new("tx_dll_in", this);
    endfunction : new


    function void check_phase(uvm_phase phase);
        super.check_phase(phase);

        // Check Write Transactions
        while(expected_rx_tlp_write_queue.size() > 0 && actual_mem_write_queue.size() > 0) begin
            tl_tlp_seq_item rx_tlp = expected_rx_tlp_write_queue.pop_front();
            mem_sequence_item mem_tlp = actual_mem_write_queue.pop_front();
            compare_write_dll(rx_tlp, mem_tlp);
        end

        // Check Read Transactions
        while(expected_rx_tlp_read_queue.size() > 0 && expected_mem_read_queue.size() > 0 && actual_tx_tlp_read_queue.size() > 0) begin
            tl_tlp_seq_item rx_tlp = expected_rx_tlp_read_queue.pop_front();
            mem_sequence_item mem_tlp = expected_mem_read_queue.pop_front();
            tl_tlp_seq_item tx_tlp = actual_tx_tlp_read_queue.pop_front();
            compare_read_dll(rx_tlp, mem_tlp, tx_tlp);
        end
    endfunction : check_phase


    function automatic void compare_write_dll(tl_tlp_seq_item tx_tlp, mem_sequence_item mem_tlp);
        int dw;
        int byte_idx;
        // Verify this is a Memory Write request
        if (tx_tlp.pkt_type != 5'b00000 || (tx_tlp.fmt != 3'b010 && tx_tlp.fmt != 3'b011)) begin
            `uvm_error("RX_SCOREBOARD", 
                    $sformatf("compare_write_dll called with non-write TLP: pkt_type=0x%h, fmt=0x%h", 
                            tx_tlp.pkt_type, tx_tlp.fmt))
            write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
            write_mismatch_mem_queue.push_back(mem_tlp);
            mismatch_write_count++;
            return;
        end
        
        // Verify TLP parameters match memory transaction
        if (tx_tlp.address != mem_tlp.addr) begin
            `uvm_error("RX_SCOREBOARD", 
                    $sformatf("Write address mismatch: TLP=0x%h, MEM=0x%h", 
                            tx_tlp.address, mem_tlp.addr))
            write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
            write_mismatch_mem_queue.push_back(mem_tlp);
            mismatch_write_count++;
            return;
        end
        
        if (tx_tlp.length != mem_tlp.length) begin
            `uvm_error("RX_SCOREBOARD", 
                    $sformatf("Write length mismatch: TLP=%0d, MEM=%0d", 
                            tx_tlp.length, mem_tlp.length))
            write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
            write_mismatch_mem_queue.push_back(mem_tlp);
            mismatch_write_count++;
            return;
        end
        
        if (tx_tlp.first_be != mem_tlp.first_be) begin
            `uvm_error("RX_SCOREBOARD", 
                    $sformatf("Write first_be mismatch: TLP=0x%h, MEM=0x%h", 
                            tx_tlp.first_be, mem_tlp.first_be))
            write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
            write_mismatch_mem_queue.push_back(mem_tlp);
            mismatch_write_count++;
            return;
        end
        
        if (tx_tlp.last_be != mem_tlp.last_be) begin
            `uvm_error("RX_SCOREBOARD", 
                    $sformatf("Write last_be mismatch: TLP=0x%h, MEM=0x%h", 
                            tx_tlp.last_be, mem_tlp.last_be))
            write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
            write_mismatch_mem_queue.push_back(mem_tlp);
            mismatch_write_count++;
            return;
        end
        
        // Compare data payload (byte-enable aware)
        for (dw = 0; dw < tx_tlp.length; dw++) begin
            bit[3:0] be;
            bit[31:0] tx_data;
            bit[31:0] mem_data;
            
            // Determine byte enables for this DW
            if (tx_tlp.length == 1) begin
                // Single DW: only first_be applies
                be = tx_tlp.first_be;
            end else if (dw == 0) begin
                // First DW
                be = tx_tlp.first_be;
            end else if (dw == tx_tlp.length - 1) begin
                // Last DW
                be = tx_tlp.last_be;
            end else begin
                // Middle DWs: all bytes enabled
                be = 4'b1111;
            end
            
            // Compare only enabled bytes
            tx_data = tx_tlp.payload_data[dw];
            mem_data = mem_tlp.payload_data[dw];
            
            for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                if (be[byte_idx]) begin  // Only check if byte is enabled
                    if (tx_data[byte_idx*8 +: 8] !== mem_data[byte_idx*8 +: 8]) begin
                        `uvm_error("RX_SCOREBOARD", 
                                $sformatf("Write Data Mismatch! DW[%0d] Byte[%0d]: TLP=0x%02h, MEM=0x%02h (BE=0x%h)",
                                        dw, byte_idx, 
                                        tx_data[byte_idx*8 +: 8], 
                                        mem_data[byte_idx*8 +: 8],
                                        be))
                        write_mismatch_dll_rx_tlp_queue.push_back(tx_tlp);
                        write_mismatch_mem_queue.push_back(mem_tlp);
                        mismatch_write_count++;
                        return;
                    end
                end
            end
        end
        
        `uvm_info("RX_SCOREBOARD", 
                $sformatf("Write TLP Match Successful! addr=0x%h len=%0d", 
                        tx_tlp.address, tx_tlp.length), UVM_MEDIUM)
        match_write_count++;
    endfunction : compare_write_dll



  function automatic void compare_read_dll(tl_tlp_seq_item rx_tlp, mem_sequence_item mem_tlp, tl_tlp_seq_item tx_tlp);
    int dw;
    int byte_idx;
    int rx_byte_count;
    if (rx_tlp.pkt_type != 5'b00000 || (rx_tlp.fmt != 3'b000 && rx_tlp.fmt != 3'b001)) begin
        `uvm_error("RX_SCOREBOARD", "compare_read_dll called with non-read rx_tlp")
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end
    
    if(rx_tlp.pkt_type != 5'b00000) begin
        `uvm_error("RX_SCOREBOARD", "compare_read_dll: rx_tlp is not a Memory Read Request")
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    if(mem_tlp.is_write) begin
        `uvm_error("RX_SCOREBOARD", "compare_read_dll: mem_tlp is not a Read transaction")
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    // Verify tx_tlp is a Completion with Data
    if (tx_tlp.pkt_type != 5'b01010) begin
        `uvm_error("RX_SCOREBOARD", "compare_read_dll: tx_tlp is not a Completion with Data (CplD)")
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end
    
    // Verify read request matches memory transaction
    if (rx_tlp.address != mem_tlp.addr || 
        rx_tlp.length != mem_tlp.length || 
        rx_tlp.first_be != mem_tlp.first_be || 
        rx_tlp.last_be != mem_tlp.last_be) begin
        `uvm_error("RX_SCOREBOARD", 
                  $sformatf("Read request/memory mismatch: RX addr=0x%h len=%0d fbe=0x%h lbe=0x%h | MEM addr=0x%h len=%0d fbe=0x%h lbe=0x%h",
                           rx_tlp.address, rx_tlp.length, rx_tlp.first_be, rx_tlp.last_be,
                           mem_tlp.addr, mem_tlp.length, mem_tlp.first_be, mem_tlp.last_be))
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    if(rx_tlp.address[6:0] != tx_tlp.lower_addr) begin
        `uvm_error("RX_SCOREBOARD", 
                  $sformatf("Read address mismatch: RX addr lower 7 bits=0x%h | CPL lower addr=0x%h",
                           rx_tlp.address[6:0], tx_tlp.lower_addr))
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    if(rx_tlp.requester_id != tx_tlp.requester_id) begin
        `uvm_error("RX_SCOREBOARD", 
                  $sformatf("Read requester ID mismatch: RX requester_id=0x%h | CPL requester_id=0x%h",
                           rx_tlp.requester_id, tx_tlp.requester_id))
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    // Calculate actual byte count based on length and byte enables
    if (rx_tlp.length == 1) begin
        // Single DW: count enabled bytes in first_be only
        rx_byte_count = $countones(rx_tlp.first_be);
    end else begin
        // Multiple DWs: first_be + middle DWs + last_be
        rx_byte_count = $countones(rx_tlp.first_be) +           // First DW
                        (rx_tlp.length - 2) * 4 +                // Middle DWs (all bytes)
                        $countones(rx_tlp.last_be);              // Last DW
    end

    // Verify completion byte_count matches calculated value
    if (tx_tlp.byte_count != rx_byte_count) begin
        `uvm_error("RX_SCOREBOARD", 
                $sformatf("Read byte_count mismatch: Expected=%0d, CPL byte_count=%0d",
                        rx_byte_count, tx_tlp.byte_count))
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end

    // Verify completion tag matches request tag
    if (tx_tlp.tag != rx_tlp.tag) begin
        `uvm_error("RX_SCOREBOARD", 
                  $sformatf("Read tag mismatch: Request tag=%0d, Completion tag=%0d",
                           rx_tlp.tag, tx_tlp.tag))
        read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
        read_mismatch_mem_queue.push_back(mem_tlp);
        read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
        mismatch_read_count++;
        return;
    end
    
    // Compare completion data with memory data (byte-enable aware)
    for (dw = 0; dw < rx_tlp.length; dw++) begin
        bit[3:0] be;
        bit[31:0] cpl_data;
        bit[31:0] mem_data;
        
        // Determine byte enables for this DW
        if (rx_tlp.length == 1) begin
            // Single DW: only first_be applies
            be = rx_tlp.first_be;
        end else if (dw == 0) begin
            // First DW
            be = rx_tlp.first_be;
        end else if (dw == rx_tlp.length - 1) begin
            // Last DW
            be = rx_tlp.last_be;
        end else begin
            // Middle DWs: all bytes enabled
            be = 4'b1111;
        end
        
        // Compare only enabled bytes
        cpl_data = tx_tlp.payload_data[dw];
        mem_data = mem_tlp.payload_data[dw];
        
        for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
            if (be[byte_idx]) begin  // Only check if byte is enabled
                if (cpl_data[byte_idx*8 +: 8] !== mem_data[byte_idx*8 +: 8]) begin
                    `uvm_error("RX_SCOREBOARD", 
                              $sformatf("Read Data Mismatch! DW[%0d] Byte[%0d]: CPL=0x%02h, MEM=0x%02h (BE=0x%h)",
                                       dw, byte_idx, 
                                       cpl_data[byte_idx*8 +: 8], 
                                       mem_data[byte_idx*8 +: 8],
                                       be))
                    read_mismatch_dll_rx_tlp_queue.push_back(rx_tlp);
                    read_mismatch_mem_queue.push_back(mem_tlp);
                    read_mismatch_dll_tx_tlp_queue.push_back(tx_tlp);
                    mismatch_read_count++;
                    return;
                end
            end
        end
    end
    
    `uvm_info("RX_SCOREBOARD", "Read TLP Match Successful!", UVM_LOW)
    match_read_count++;
  endfunction : compare_read_dll


    int total_transactions;
    int total_passed;
    int total_failed;

function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    total_transactions = match_write_count + mismatch_write_count + match_read_count + mismatch_read_count;
    total_passed = match_write_count + match_read_count;
    total_failed = mismatch_write_count + mismatch_read_count;
    
    `uvm_info("RX_SCOREBOARD", "========================================", UVM_LOW)
    `uvm_info("RX_SCOREBOARD", "     RX Scoreboard Final Report        ", UVM_LOW)
    `uvm_info("RX_SCOREBOARD", "========================================", UVM_LOW)
    
    `uvm_info("RX_SCOREBOARD", $sformatf("Total Transactions:     %0d", total_transactions), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", "", UVM_LOW)
    
    `uvm_info("RX_SCOREBOARD", "--- Memory Write Path ---", UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Matched Writes:       %0d", match_write_count), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Mismatched Writes:    %0d", mismatch_write_count), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", "", UVM_LOW)
    
    `uvm_info("RX_SCOREBOARD", "--- Memory Read Path ---", UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Matched Reads:        %0d", match_read_count), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Mismatched Reads:     %0d", mismatch_read_count), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", "", UVM_LOW)
    
    `uvm_info("RX_SCOREBOARD", "--- Summary ---", UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Total Passed:         %0d", total_passed), UVM_LOW)
    `uvm_info("RX_SCOREBOARD", $sformatf("  Total Failed:         %0d", total_failed), UVM_LOW)
    
    if (total_failed > 0) begin
      `uvm_info("RX_SCOREBOARD", $sformatf("  Pass Rate:            %.2f%%", 
                                           (real'(total_passed) / real'(total_transactions)) * 100.0), UVM_LOW)
    end else if (total_transactions > 0) begin
      `uvm_info("RX_SCOREBOARD", "  Pass Rate:            100.00%", UVM_LOW)
    end
    
    `uvm_info("RX_SCOREBOARD", "========================================", UVM_LOW)
    
    // Report detailed mismatch information for WRITE transactions
    if (write_mismatch_dll_rx_tlp_queue.size() > 0) begin
      `uvm_error("RX_SCOREBOARD", $sformatf("\n%0d WRITE TRANSACTION(S) FAILED TO MATCH:", 
                                             write_mismatch_dll_rx_tlp_queue.size()))
      
      for (int i = 0; i < write_mismatch_dll_rx_tlp_queue.size(); i++) begin
        `uvm_info("RX_SCOREBOARD", $sformatf("\n  --- Write Mismatch #%0d ---", i+1), UVM_LOW)
        `uvm_info("RX_SCOREBOARD", "  Expected TLP (from RX DLL):", UVM_LOW)
        write_mismatch_dll_rx_tlp_queue[i].print();
        
        if (i < write_mismatch_mem_queue.size()) begin
          `uvm_info("RX_SCOREBOARD", "  Actual Memory Transaction:", UVM_LOW)
          write_mismatch_mem_queue[i].print();
        end
      end
    end
    
    // Report detailed mismatch information for READ transactions
    if (read_mismatch_dll_rx_tlp_queue.size() > 0) begin
      `uvm_error("RX_SCOREBOARD", $sformatf("\n%0d READ TRANSACTION(S) FAILED TO MATCH:", 
                                             read_mismatch_dll_rx_tlp_queue.size()))
      
      for (int i = 0; i < read_mismatch_dll_rx_tlp_queue.size(); i++) begin
        `uvm_info("RX_SCOREBOARD", $sformatf("\n  --- Read Mismatch #%0d ---", i+1), UVM_LOW)
        `uvm_info("RX_SCOREBOARD", "  Expected Read Request (from RX DLL):", UVM_LOW)
        read_mismatch_dll_rx_tlp_queue[i].print();
        
        if (i < read_mismatch_mem_queue.size()) begin
          `uvm_info("RX_SCOREBOARD", "  Expected Memory Read Transaction:", UVM_LOW)
          read_mismatch_mem_queue[i].print();
        end
        
        if (i < read_mismatch_dll_tx_tlp_queue.size()) begin
          `uvm_info("RX_SCOREBOARD", "  Actual Completion (from TX DLL):", UVM_LOW)
          read_mismatch_dll_tx_tlp_queue[i].print();
        end
      end
    end
    
    // Report any unmatched pending transactions
    if (expected_rx_tlp_write_queue.size() > 0) begin
      `uvm_warning("RX_SCOREBOARD", $sformatf("\n%0d unmatched RX WRITE TLP(s) still pending", 
                                               expected_rx_tlp_write_queue.size()))
    end
    
    if (actual_mem_write_queue.size() > 0) begin
      `uvm_warning("RX_SCOREBOARD", $sformatf("%0d unmatched MEMORY WRITE transaction(s) still pending", 
                                               actual_mem_write_queue.size()))
    end
    
    if (expected_rx_tlp_read_queue.size() > 0) begin
      `uvm_warning("RX_SCOREBOARD", $sformatf("%0d unmatched RX READ TLP(s) still pending", 
                                               expected_rx_tlp_read_queue.size()))
    end
    
    if (expected_mem_read_queue.size() > 0) begin
      `uvm_warning("RX_SCOREBOARD", $sformatf("%0d unmatched MEMORY READ transaction(s) still pending", 
                                               expected_mem_read_queue.size()))
    end
    
    if (actual_tx_tlp_read_queue.size() > 0) begin
      `uvm_warning("RX_SCOREBOARD", $sformatf("%0d unmatched TX COMPLETION(s) still pending", 
                                               actual_tx_tlp_read_queue.size()))
    end
    
    `uvm_info("RX_SCOREBOARD", "========================================", UVM_LOW)
    
    // Final pass/fail determination
    if (total_failed > 0) begin
      `uvm_error("RX_SCOREBOARD", $sformatf("\n*** VERIFICATION FAILED: %0d transaction(s) mismatched! ***\n", total_failed))
    end else if (total_transactions > 0) begin
      `uvm_info("RX_SCOREBOARD", "\n*** VERIFICATION PASSED: All transactions matched successfully! ***\n", UVM_LOW)
    end else begin
      `uvm_warning("RX_SCOREBOARD", "No transactions were checked")
    end
endfunction : report_phase
endclass : rx_scoreboard