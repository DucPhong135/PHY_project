`ifndef CPL_SCOREBOARD_SV
`define CPL_SCOREBOARD_SV

class cpl_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(cpl_scoreboard);


  // Queues to hold expected and actual completions
  tl_user_seq_item actual_cpls[$];
  tl_tlp_seq_item expected_cpls[$];

  tl_user_seq_item mismatched_mem_read_cpls[$];
  tl_tlp_seq_item mismatched_mem_read_dll_cpls[$];

  tl_user_seq_item mismatched_cfg_read_cpls[$];
  tl_tlp_seq_item mismatched_cfg_read_dll_cpls[$];

  tl_user_seq_item mismatched_cfg_write_cpls[$];
  tl_tlp_seq_item mismatched_cfg_write_dll_cpls[$];


  int unsigned num_matches = 0;
  int unsigned num_mem_read_mismatches = 0;
  int unsigned num_cfg_read_mismatches = 0;
  int unsigned num_cfg_write_mismatches = 0;

  
  `uvm_analysis_imp_decl(_user_cpl)

  uvm_analysis_imp_user_cpl #(tl_user_seq_item, cpl_scoreboard) user_cpl_ap;

  `uvm_analysis_imp_decl(_dll_cpl)

  uvm_analysis_imp_dll_cpl #(tl_tlp_seq_item, cpl_scoreboard) dll_cpl_ap;

  function write_user_cpl(tl_user_seq_item item);
    tl_user_seq_item item_copy;
    $cast(item_copy, item.clone());
    actual_cpls.push_back(item_copy);
    `uvm_info("CPL_SB", $sformatf("Received actual completion from user monitor. Total actual completions: %0d", actual_cpls.size()), UVM_LOW);

    `uvm_info("CPL_SB", $sformatf("Actual CPL:"), UVM_LOW);
    item_copy.print();
  endfunction

  function write_dll_cpl(tl_tlp_seq_item item);
    tl_tlp_seq_item item_copy;
    $cast(item_copy, item.clone());
    expected_cpls.push_back(item_copy);
    `uvm_info("CPL_SB", $sformatf("Received expected completion from DLL monitor. Total expected completions: %0d", expected_cpls.size()), UVM_LOW);
    `uvm_info("CPL_SB", $sformatf("Expected CPL:"), UVM_LOW);
    item_copy.print();
  endfunction


  function new(string name = "cpl_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    user_cpl_ap = new("user_cpl_ap", this);
    dll_cpl_ap = new("dll_cpl_ap", this);
  endfunction

  function bit compare_cpls(tl_user_seq_item user_cpl, tl_tlp_seq_item dll_cpl);
    int i = 0;
    int unsigned byte_count_cpl;
    if(user_cpl.is_response != 1'b1) begin
      `uvm_error("CPL_SB", "User completion item is not marked as a response");
      return 0;
    end
    // Compare relevant fields
    case(user_cpl.trans_type)
      CMD_MEM: begin

        // Calculate byte count from completion based on length and byte enables
        if (user_cpl.length_dw == 1) begin
          // Single DW: only first_be applies
          byte_count_cpl = $countones(user_cpl.first_be);
        end else begin
          // Multiple DWs: first_be + middle DWs + last_be
          byte_count_cpl = $countones(user_cpl.first_be) + 
                          (user_cpl.length_dw - 2) * 4 + 
                          $countones(user_cpl.last_be);
        end
        if(byte_count_cpl != dll_cpl.byte_count) begin
          `uvm_error("CPL_SB", $sformatf("Memory Read Completion Length Mismatch: User Length=%0d, DLL Length=%0d", byte_count_cpl, dll_cpl.byte_count));
          mismatched_mem_read_cpls.push_back(user_cpl);
          mismatched_mem_read_dll_cpls.push_back(dll_cpl);
          num_mem_read_mismatches++;
          return 0;
        end

        for(i = 0; i < user_cpl.length_dw; i++) begin
          if(user_cpl.data_payload[i] != dll_cpl.payload_data[i]) begin
            `uvm_error("CPL_SB", $sformatf("Memory Read Completion Data Mismatch at DW %0d: User Data=0x%0h, DLL Data=0x%0h", i, user_cpl.data_payload[i], dll_cpl.payload_data[i]));
            mismatched_mem_read_cpls.push_back(user_cpl);
            mismatched_mem_read_dll_cpls.push_back(dll_cpl);
            num_mem_read_mismatches++;
            return 0;
          end
        end
      end
      CMD_CFG: begin
        if(dll_cpl.byte_count == 11'd0) begin
          if (user_cpl.tag != dll_cpl.tag) begin
            `uvm_error("CPL_SB", $sformatf("Config Completion Tag Mismatch: User Tag=0x%0h, DLL Tag=0x%0h", user_cpl.tag, dll_cpl.tag));
            mismatched_cfg_write_cpls.push_back(user_cpl);
            mismatched_cfg_write_dll_cpls.push_back(dll_cpl);
            num_cfg_write_mismatches++;
            return 0;
          end

          if (user_cpl.status != dll_cpl.status) begin
            `uvm_error("CPL_SB", $sformatf("Config Completion Status Mismatch: User Status=0x%0h, DLL Status=0x%0h", user_cpl.status, dll_cpl.status));
            mismatched_cfg_write_cpls.push_back(user_cpl);
            mismatched_cfg_write_dll_cpls.push_back(dll_cpl);
            num_cfg_write_mismatches++;
            return 0;
          end

          if({user_cpl.bus, user_cpl.device, user_cpl.function_num} != dll_cpl.completer_id) begin
            `uvm_error("CPL_SB", $sformatf("Config Completion Bus/Device/Function Mismatch: User BDF=0x%0h, DLL BDF=0x%0h", 
              {user_cpl.bus, user_cpl.device, user_cpl.function_num},
              dll_cpl.completer_id));
            mismatched_cfg_write_cpls.push_back(user_cpl);
            mismatched_cfg_write_dll_cpls.push_back(dll_cpl);
            num_cfg_write_mismatches++;
            return 0;
          end
        end
        else begin
          if (user_cpl.tag != dll_cpl.tag) begin
            `uvm_error("CPL_SB", $sformatf("Config Read Completion Tag Mismatch: User Tag=0x%0h, DLL Tag=0x%0h", user_cpl.tag, dll_cpl.tag));
            mismatched_cfg_read_cpls.push_back(user_cpl);
            mismatched_cfg_read_dll_cpls.push_back(dll_cpl);
            num_cfg_read_mismatches++;
            return 0;
          end

          if (user_cpl.status != dll_cpl.status) begin
            `uvm_error("CPL_SB", $sformatf("Config Read Completion Status Mismatch: User Status=0x%0h, DLL Status=0x%0h", user_cpl.status, dll_cpl.status));
            mismatched_cfg_read_cpls.push_back(user_cpl);
            mismatched_cfg_read_dll_cpls.push_back(dll_cpl);
            num_cfg_read_mismatches++;
            return 0;
          end

          if({user_cpl.bus, user_cpl.device, user_cpl.function_num} != dll_cpl.completer_id) begin
            `uvm_error("CPL_SB", $sformatf("Config Completion Bus/Device/Function Mismatch: User BDF=0x%0h, DLL BDF=0x%0h", 
              {user_cpl.bus, user_cpl.device, user_cpl.function_num},
              dll_cpl.completer_id));
            mismatched_cfg_read_cpls.push_back(user_cpl);
            mismatched_cfg_read_dll_cpls.push_back(dll_cpl);
            num_cfg_read_mismatches++;
            return 0;
          end

          if(user_cpl.config_data != dll_cpl.config_data) begin
            `uvm_error("CPL_SB", $sformatf("Config Read Completion Data Mismatch: User Data=0x%0h, DLL Data=0x%0h", user_cpl.config_data, dll_cpl.config_data));
            mismatched_cfg_read_cpls.push_back(user_cpl);
            mismatched_cfg_read_dll_cpls.push_back(dll_cpl);
            num_cfg_read_mismatches++;
            return 0;
          end
        end
      end
      default: begin
        `uvm_error("CPL_SB", $sformatf("Unknown transaction type in completion comparison: %0d", user_cpl.trans_type));
        return 0;
      end
    endcase

    `uvm_info("CPL_SB", "Completion match successful", UVM_LOW);
    num_matches++;
        return 1; // Match
  endfunction

  function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if(actual_cpls.size() != expected_cpls.size()) begin
      `uvm_error("CPL_SB", $sformatf("Mismatch in number of completions: Actual=%0d, Expected=%0d", actual_cpls.size(), expected_cpls.size()));
      return;
    end

    for (int i = 0; i < actual_cpls.size(); i++) begin
      compare_cpls(actual_cpls[i], expected_cpls[i]);
    end
  endfunction

  function void report_phase(uvm_phase phase);
  string report_str;
  super.report_phase(phase);
  
  
  // ─────────────────────────────────────────────────────────────
  // Summary Statistics
  // ─────────────────────────────────────────────────────────────
  `uvm_info("CPL_SB", "========================================", UVM_NONE)
  `uvm_info("CPL_SB", "     COMPLETION SCOREBOARD REPORT      ", UVM_NONE)
  `uvm_info("CPL_SB", "========================================", UVM_NONE)
  
  report_str = $sformatf("\n");
  report_str = {report_str, $sformatf("  Total Actual Completions:    %0d\n", actual_cpls.size())};
  report_str = {report_str, $sformatf("  Total Expected Completions:  %0d\n", expected_cpls.size())};
  report_str = {report_str, $sformatf("  Total Matches:               %0d\n", num_matches)};
  report_str = {report_str, $sformatf("  Memory Read Mismatches:      %0d\n", num_mem_read_mismatches)};
  report_str = {report_str, $sformatf("  Config Read Mismatches:      %0d\n", num_cfg_read_mismatches)};
  report_str = {report_str, $sformatf("  Config Write Mismatches:     %0d\n", num_cfg_write_mismatches)};
  report_str = {report_str, $sformatf("  Total Mismatches:            %0d\n", 
                num_mem_read_mismatches + num_cfg_read_mismatches + num_cfg_write_mismatches)};
  
  `uvm_info("CPL_SB", report_str, UVM_NONE)
  
  // ─────────────────────────────────────────────────────────────
  // Memory Read Completion Mismatches
  // ─────────────────────────────────────────────────────────────
  if (num_mem_read_mismatches > 0) begin
    `uvm_error("CPL_SB", $sformatf("\n========================================"))
    `uvm_error("CPL_SB", $sformatf("  MEMORY READ COMPLETION MISMATCHES (%0d)", num_mem_read_mismatches))
    `uvm_error("CPL_SB", $sformatf("========================================"))
    
    for (int i = 0; i < mismatched_mem_read_cpls.size(); i++) begin
      `uvm_error("CPL_SB", $sformatf("\n--- Mismatch #%0d ---", i+1))
      
      `uvm_error("CPL_SB", "ACTUAL (User Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Addr:      0x%0h", mismatched_mem_read_cpls[i].addr))
      `uvm_error("CPL_SB", $sformatf("  Length:    %0d DW", mismatched_mem_read_cpls[i].length_dw))
      `uvm_error("CPL_SB", $sformatf("  First BE:  0x%h", mismatched_mem_read_cpls[i].first_be))
      `uvm_error("CPL_SB", $sformatf("  Last BE:   0x%h", mismatched_mem_read_cpls[i].last_be))
      `uvm_error("CPL_SB", $sformatf("  Status:    0x%0h", mismatched_mem_read_cpls[i].status))
      
      // Print data payload
      if (mismatched_mem_read_cpls[i].data_payload.size() > 0) begin
        `uvm_error("CPL_SB", "  Data Payload (Actual):")
        for (int dw = 0; dw < mismatched_mem_read_cpls[i].data_payload.size(); dw++) begin
          `uvm_error("CPL_SB", $sformatf("    [%0d]: 0x%08h", dw, mismatched_mem_read_cpls[i].data_payload[dw]))
        end
      end
      
      `uvm_error("CPL_SB", "EXPECTED (DLL Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Addr:      0x%0h", mismatched_mem_read_dll_cpls[i].address))
      `uvm_error("CPL_SB", $sformatf("  Length:    %0d DW", mismatched_mem_read_dll_cpls[i].length))
      `uvm_error("CPL_SB", $sformatf("  Tag:       0x%0h", mismatched_mem_read_dll_cpls[i].tag))
      `uvm_error("CPL_SB", $sformatf("  Status:    0x%0h", mismatched_mem_read_dll_cpls[i].status))
      
      // Print data payload
      if (mismatched_mem_read_dll_cpls[i].payload_data.size() > 0) begin
        `uvm_error("CPL_SB", "  Data Payload (Expected):")
        for (int dw = 0; dw < mismatched_mem_read_dll_cpls[i].payload_data.size(); dw++) begin
          `uvm_error("CPL_SB", $sformatf("    [%0d]: 0x%08h", dw, mismatched_mem_read_dll_cpls[i].payload_data[dw]))
        end
      end
      
      // Print full objects for detailed debug
      `uvm_error("CPL_SB", "\nFull Actual Object:")
      mismatched_mem_read_cpls[i].print();
      `uvm_error("CPL_SB", "\nFull Expected Object:")
      mismatched_mem_read_dll_cpls[i].print();
    end
  end
  
  // ─────────────────────────────────────────────────────────────
  // Config Read Completion Mismatches
  // ─────────────────────────────────────────────────────────────
  if (num_cfg_read_mismatches > 0) begin
    `uvm_error("CPL_SB", $sformatf("\n========================================"))
    `uvm_error("CPL_SB", $sformatf("  CONFIG READ COMPLETION MISMATCHES (%0d)", num_cfg_read_mismatches))
    `uvm_error("CPL_SB", $sformatf("========================================"))
    
    for (int i = 0; i < mismatched_cfg_read_cpls.size(); i++) begin
      `uvm_error("CPL_SB", $sformatf("\n--- Mismatch #%0d ---", i+1))
      
      `uvm_error("CPL_SB", "ACTUAL (User Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Tag:         0x%0h", mismatched_cfg_read_cpls[i].tag))
      `uvm_error("CPL_SB", $sformatf("  Status:      0x%0h", mismatched_cfg_read_cpls[i].status))
      `uvm_error("CPL_SB", $sformatf("  Bus/Device/Function: 0x%0h", 
        {mismatched_cfg_read_cpls[i].bus, mismatched_cfg_read_cpls[i].device, mismatched_cfg_read_cpls[i].function_num}))
      `uvm_error("CPL_SB", $sformatf("  Config Data: 0x%08h", mismatched_cfg_read_cpls[i].config_data))
      
      `uvm_error("CPL_SB", "EXPECTED (DLL Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Tag:         0x%0h", mismatched_cfg_read_dll_cpls[i].tag))
      `uvm_error("CPL_SB", $sformatf("  Status:      0x%0h", mismatched_cfg_read_dll_cpls[i].status))
      `uvm_error("CPL_SB", $sformatf("  Bus/Device/Function: 0x%0h", 
        mismatched_cfg_read_dll_cpls[i].completer_id))
      `uvm_error("CPL_SB", $sformatf("  Config Data: 0x%08h", mismatched_cfg_read_dll_cpls[i].config_data))
      
      // Print full objects
      `uvm_error("CPL_SB", "\nFull Actual Object:")
      mismatched_cfg_read_cpls[i].print();
      `uvm_error("CPL_SB", "\nFull Expected Object:")
      mismatched_cfg_read_dll_cpls[i].print();
    end
  end
  
  // ─────────────────────────────────────────────────────────────
  // Config Write Completion Mismatches
  // ─────────────────────────────────────────────────────────────
  if (num_cfg_write_mismatches > 0) begin
    `uvm_error("CPL_SB", $sformatf("\n========================================"))
    `uvm_error("CPL_SB", $sformatf("  CONFIG WRITE COMPLETION MISMATCHES (%0d)", num_cfg_write_mismatches))
    `uvm_error("CPL_SB", $sformatf("========================================"))
    
    for (int i = 0; i < mismatched_cfg_write_cpls.size(); i++) begin
      `uvm_error("CPL_SB", $sformatf("\n--- Mismatch #%0d ---", i+1))
      
      `uvm_error("CPL_SB", "ACTUAL (User Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Tag:    0x%0h", mismatched_cfg_write_cpls[i].tag))
      `uvm_error("CPL_SB", $sformatf("  Status: 0x%0h", mismatched_cfg_write_cpls[i].status))
      
      `uvm_error("CPL_SB", "EXPECTED (DLL Monitor):")
      `uvm_error("CPL_SB", $sformatf("  Tag:    0x%0h", mismatched_cfg_write_dll_cpls[i].tag))
      `uvm_error("CPL_SB", $sformatf("  Status: 0x%0h", mismatched_cfg_write_dll_cpls[i].status))
      
      // Print full objects
      `uvm_error("CPL_SB", "\nFull Actual Object:")
      mismatched_cfg_write_cpls[i].print();
      `uvm_error("CPL_SB", "\nFull Expected Object:")
      mismatched_cfg_write_dll_cpls[i].print();
    end
  end
  
  // ─────────────────────────────────────────────────────────────
  // Final Pass/Fail Status
  // ─────────────────────────────────────────────────────────────
  `uvm_info("CPL_SB", "========================================", UVM_NONE)
  
  if (num_mem_read_mismatches == 0 && 
      num_cfg_read_mismatches == 0 && 
      num_cfg_write_mismatches == 0 &&
      actual_cpls.size() == expected_cpls.size()) begin
    `uvm_info("CPL_SB", "  TEST PASSED - All completions matched!", UVM_NONE)
  end else begin
    `uvm_error("CPL_SB", "  TEST FAILED - Mismatches detected!")
  end
  
  `uvm_info("CPL_SB", "========================================", UVM_NONE)
  
endfunction : report_phase

endclass: cpl_scoreboard

`endif // CPL_SCOREBOARD_SV