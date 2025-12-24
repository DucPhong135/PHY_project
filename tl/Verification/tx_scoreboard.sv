`ifndef TX_SCOREBOARD_SV
`define TX_SCOREBOARD_SV

class tx_scoreboard extends uvm_scoreboard;

  `uvm_component_utils(tx_scoreboard);

  tl_user_seq_item expected_user[$];
  tl_tlp_seq_item mismatch_tlp[$];

  int num_matches = 0;
  int num_mismatches = 0;

  bit[7:0] bus_num = 8'h0;
  bit[4:0] device_num = 5'd10;
  bit[2:0] function_num = 3'd4;


  `uvm_analysis_imp_decl(_user);
  `uvm_analysis_imp_decl(_dll);
  uvm_analysis_imp_user #(tl_user_seq_item, tx_scoreboard) user_ap;
  uvm_analysis_imp_dll #(tl_tlp_seq_item, tx_scoreboard) dll_ap;


  // Constructor
  function new(string name = "tx_scoreboard", uvm_component parent = null);
    super.new(name, parent);
    user_ap = new("user_ap", this);
    dll_ap = new("dll_ap", this);
  endfunction

  function void write_user(tl_user_seq_item user);
    tl_user_seq_item expected;
    $cast(expected, user.clone());
    `uvm_info("TX_SCOREBOARD", $sformatf("Received User: %s", expected.sprint()), UVM_LOW)
    expected_user.push_back(expected);
  endfunction

  function void write_dll(tl_tlp_seq_item tlp);
    tl_tlp_seq_item actual;
    tl_user_seq_item expected;
    if (tlp == null) begin
        `uvm_error("TX_SCOREBOARD", "Received null user transaction")
        return;
    end
    $cast(actual, tlp.clone());
    `uvm_info("TX_SCOREBOARD", $sformatf("Received dll: %s", actual.sprint()), UVM_LOW)
    if (expected_user.size() == 0) begin
        `uvm_error("TX_SCOREBOARD", $sformatf(
        "No expected user transaction to match against TLP (Tag=0x%02h)",
        tlp.tag))
        mismatch_tlp.push_back(actual);
        return;
    end
    expected = expected_user.pop_front();
    if (compare_transactions(expected, tlp)) begin
        if(expected.trans_type == CMD_MEM) begin
            `uvm_info("TX_SCOREBOARD", $sformatf(
                "MATCH: User command matched TLP\n  Expected: %s %s Addr=0x%016h Len=%0dDW\n  Actual:   %s Addr=0x%016h Len=%0dDW Tag=0x%02h",
                expected.trans_type.name(),
                expected.is_write ? "Write" : "Read",
                expected.addr,
                expected.length_dw,
                actual.get_type_str(),
                actual.address,
                actual.length,
                actual.tag), UVM_LOW)
        end
        else begin
            `uvm_info("TX_SCOREBOARD", $sformatf(
                "MATCH: User command matched TLP\n  Expected: %s %s Bus=%0d Dev=%0d Func=%0d Reg=%0d Config_data=0'h%0h\n  Actual:   %s Bus=%0d Dev=%0d Func=%0d Reg=%0d Config_data=0'h%0h Tag=0x%02h",
                expected.trans_type.name(),
                expected.is_write ? "Write" : "Read",
                expected.bus,
                expected.device,
                expected.function_num,
                expected.reg_num,
                expected.config_data,
                actual.get_type_str(),
                actual.bus_number,
                actual.device_number,
                actual.function_number,
                actual.register_number,
                actual.config_data,
                actual.tag), UVM_LOW)
        end
        num_matches++;
    end
    else begin
        if(expected.trans_type == CMD_MEM) begin
            `uvm_error("TX_SCOREBOARD", {
          "MISMATCH: Expected and actual transactions differ\n",
          $sformatf("  Expected: %s %s Addr=0x%016h Len=%0dDW\n",
              expected.trans_type.name(),
              expected.is_write ? "Write" : "Read",
              expected.addr,
              expected.length_dw),
          $sformatf("  Actual:   %s Addr=0x%016h Len=%0dDW Tag=0x%02h",
              actual.get_type_str(),
              actual.address,
              actual.length,
              actual.tag)
        });
        end
        else begin
            `uvm_error("TX_SCOREBOARD", {
          "MISMATCH: Expected and actual transactions differ\n",
          $sformatf("  Expected: %s %s Bus=%0d Dev=%0d Func=%0d Reg=%0d Config_data=0'h%0h\n",
                expected.trans_type.name(),
                expected.is_write ? "Write" : "Read",
                expected.bus,
                expected.device,
                expected.function_num,
                expected.reg_num,
                expected.config_data),
          $sformatf("  Actual:   %s Bus=%0d Dev=%0d Func=%0d Reg=%0d Config_data=0'h%0h Tag=0x%02h",
              actual.get_type_str(),
              actual.bus_number,
              actual.device_number,
              actual.function_number,
              actual.register_number,
              actual.config_data,
              actual.tag)
        });
        end
        num_mismatches++;
        mismatch_tlp.push_back(actual);
    end
  endfunction

  function bit compare_transactions(tl_user_seq_item user, tl_tlp_seq_item tlp);
    int i;
    bit [63:0] expected_cfg_addr;
    bit [15:0] expected_req_id;
    bit [2:0] expected_fmt;
    bit [4:0] expected_type;
    bit [3:0] expected_first_be, expected_last_be;
    int expected_length_dw;
    bit is_non_posted;
    bit [1:0] start_offset;
    int total_bytes;
    
    case (user.trans_type)
    CMD_MEM: begin
      if (user.is_write) begin
        // Memory Write Request
        expected_fmt  = (user.addr[63:32] != 0) ? 3'b011 : 3'b010; // 4DW or 3DW with data
        expected_type = 5'b00000; // MWr
      end
      else begin
        // Memory Read Request
        expected_fmt  = (user.addr[63:32] != 0) ? 3'b001 : 3'b000; // 4DW or 3DW no data
        expected_type = 5'b00000; // MRd
      end
    end
    
    CMD_CFG: begin
      if (user.is_write) begin
        // Config Write Type 0
        expected_fmt  = 3'b010; // 3DW with data
        expected_type = 5'b00100; // CfgWr0
      end
      else begin
        // Config Read Type 0
        expected_fmt  = 3'b000; // 3DW no data
        expected_type = 5'b00100; // CfgRd0
      end
    end
    
    default: begin
      `uvm_error("TX_SCB_CMP", $sformatf(
        "Unknown transaction type: %s", user.trans_type.name()))
      return 0;
    end
    endcase

    if (tlp.fmt != expected_fmt) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
        "Format mismatch: Expected=0x%0h, Actual=0x%0h",
        expected_fmt, tlp.fmt))
        return 0;
    end
  
    // Compare type field
    if (tlp.pkt_type != expected_type) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
            "Type mismatch: Expected=0x%02h, Actual=0x%02h",
            expected_type, tlp.pkt_type))
        return 0;
    end

    if (user.trans_type == CMD_MEM) begin
        bit [63:0] expected_addr = {user.addr[63:2], 2'b00};
    
        if (tlp.address != expected_addr) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
            "Address mismatch:\n  Expected: 0x%016h\n  Actual:   0x%016h",
            expected_addr, tlp.address))
        return 0;
        end
    end
    else begin
        // Config transaction - check 32-bit config address mapping
        bit [7:0] expected_cfg_bus = user.bus;
        bit [4:0] expected_cfg_device = user.device;
        bit [2:0] expected_cfg_function = user.function_num;
        bit [9:0] expected_cfg_reg = user.reg_num;

        if (tlp.bus_number != expected_cfg_bus ||
            tlp.device_number != expected_cfg_device ||
            tlp.function_number != expected_cfg_function ||
            tlp.register_number != expected_cfg_reg) begin
            `uvm_error("TX_SCB_CMP", $sformatf(
                "Config address mismatch: Expected Bus=%0d Dev=%0d Func=%0d Reg=%0d, Actual Bus=%0d Dev=%0d Func=%0d Reg=%0d",
                expected_cfg_bus, expected_cfg_device, expected_cfg_function, expected_cfg_reg,
                tlp.bus_number, tlp.device_number, tlp.function_number, tlp.register_number))
            return 0;
        end
    end
    if (tlp.length != user.length_dw) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
        "Length mismatch: Expected=%0d DW, Actual=%0d DW",
        user.length_dw, tlp.length))
        return 0;
    end


    expected_req_id = {bus_num, device_num, function_num};
  
    if (tlp.requester_id != expected_req_id) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
        "Requester ID mismatch: Expected=0x%04h, Actual=0x%04h",
        expected_req_id, tlp.requester_id))
        return 0;
    end

    if(user.trans_type == CMD_CFG) begin
        expected_first_be = 4'b1111;
        expected_last_be = 4'b0000;
    end
    else if(user.trans_type == CMD_MEM) begin

        start_offset = user.addr[1:0];
        total_bytes = user.length_dw * 4;
    
        case (start_offset)
            2'b00: expected_first_be = 4'b1111;
            2'b01: expected_first_be = 4'b1110;
            2'b10: expected_first_be = 4'b1100;
            2'b11: expected_first_be = 4'b1000;
        endcase
        if(tlp.length == 1) begin
            expected_last_be = 4'b0000;
        end
        else begin
            expected_last_be = 4'b1111;
        end
    end

    if (tlp.first_be != expected_first_be) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
        "First BE mismatch: Expected=0b%04b, Actual=0b%04b (offset=%0d)",
        expected_first_be, tlp.first_be, start_offset))
        return 0;
    end
  
    if (tlp.last_be != expected_last_be) begin
        `uvm_error("TX_SCB_CMP", $sformatf(
        "Last BE mismatch: Expected=0b%04b, Actual=0b%04b",
        expected_last_be, tlp.last_be))
        return 0;
    end


    if (user.is_write && user.trans_type == CMD_MEM) begin
        for(i = 0; i < user.length_dw; i++) begin
            if (user.data_payload[i] !== tlp.payload_data[i]) begin
                `uvm_error("TX_SCB_CMP", $sformatf(
                    "Memory write data mismatch at DW %0d: Expected=0x%08h, Actual=0x%08h",
                    i, user.data_payload[i], tlp.payload_data[i]))
                return 0;
            end
        end
    end
    else if(user.is_write && user.trans_type == CMD_CFG) begin
        if(tlp.config_data !== user.config_data) begin
            `uvm_error("TX_SCB_CMP", $sformatf(
                "Config write data mismatch: Expected=0x%08h, Actual=0x%08h",
                user.config_data, tlp.config_data))
            return 0;
        end
    end
    else begin
        if (tlp.payload_data.size() != 0) begin
            `uvm_error("TX_SCB_CMP", $sformatf(
                "Read request has unexpected payload: %0d DW",
                tlp.payload_data.size()))
            return 0;
        end
    end
    return 1'b1;
  endfunction
  

function void report_phase(uvm_phase phase);
    string report_str;
    int pass_rate;
    int total_transactions;
    super.report_phase(phase);
    
    
    total_transactions = num_matches + num_mismatches;
    
    if (total_transactions > 0) begin
        pass_rate = (num_matches * 100) / total_transactions;
    end
    else begin
        pass_rate = 0;
    end
    
    
    report_str = "\n";
    report_str = {report_str, "========================================================================\n"};
    report_str = {report_str, "                    TX SCOREBOARD FINAL REPORT                         \n"};
    report_str = {report_str, "========================================================================\n\n"};
    
    //------------------------------------------------------------------
    // Summary Statistics
    //------------------------------------------------------------------
    
    report_str = {report_str, "--- TRANSACTION SUMMARY ---\n"};
    report_str = {report_str, $sformatf("  Total Transactions   : %0d\n", total_transactions)};
    report_str = {report_str, $sformatf(" Matches          : %0d\n", num_matches)};
    report_str = {report_str, $sformatf(" Mismatches       : %0d\n", num_mismatches)};
    report_str = {report_str, $sformatf("  Pass Rate           : %0d%%\n\n", pass_rate)};
    
    //------------------------------------------------------------------
    // Queue Status
    //------------------------------------------------------------------
    
    report_str = {report_str, "--- QUEUE STATUS ---\n"};
    report_str = {report_str, $sformatf("  Unmatched User Cmds : %0d\n", expected_user.size())};
    report_str = {report_str, $sformatf("  Mismatched TLPs     : %0d\n\n", mismatch_tlp.size())};
    
    //------------------------------------------------------------------
    // Test Result
    //------------------------------------------------------------------
    
    report_str = {report_str, "--- TEST RESULT ---\n"};
    
    if (num_mismatches == 0 && expected_user.size() == 0) begin
        report_str = {report_str, "  Status: PASS - All transactions matched!\n\n"};
    end
    else if (num_mismatches > 0) begin
        report_str = {report_str, $sformatf("  Status: FAIL - %0d mismatches detected\n\n", num_mismatches)};
    end
    else if (expected_user.size() > 0) begin
        report_str = {report_str, $sformatf("  Status: INCOMPLETE - %0d user commands not matched by TLPs\n\n", expected_user.size())};
    end
    
    //------------------------------------------------------------------
    // Detailed Mismatch Report
    //------------------------------------------------------------------
    
    if (mismatch_tlp.size() > 0) begin
        report_str = {report_str, "========================================================================\n"};
        report_str = {report_str, "                         MISMATCH DETAILS                              \n"};
        report_str = {report_str, "========================================================================\n\n"};
        
        foreach (mismatch_tlp[i]) begin
            tl_tlp_seq_item tlp = mismatch_tlp[i];
            
            report_str = {report_str, $sformatf("--- Mismatch #%0d ---\n", i+1)};
            report_str = {report_str, $sformatf("  TLP Type      : %s\n", tlp.get_type_str())};
            report_str = {report_str, $sformatf("  Format        : 0x%0h (%s)\n", 
                tlp.fmt, get_fmt_str(tlp.fmt))};
            report_str = {report_str, $sformatf("  Packet Type   : 0x%02h\n", tlp.pkt_type)};
            report_str = {report_str, $sformatf("  Address       : 0x%016h\n", tlp.address)};
            report_str = {report_str, $sformatf("  Length        : %0d DW (%0d bytes)\n", 
                tlp.length, tlp.length * 4)};
            report_str = {report_str, $sformatf("  Tag           : 0x%02h\n", tlp.tag)};
            report_str = {report_str, $sformatf("  Requester ID  : 0x%04h (Bus=%0d Dev=%0d Func=%0d)\n",
                tlp.requester_id,
                tlp.requester_id[15:8],
                tlp.requester_id[7:3],
                tlp.requester_id[2:0])};
            report_str = {report_str, $sformatf("  First BE      : 0b%04b\n", tlp.first_be)};
            report_str = {report_str, $sformatf("  Last BE       : 0b%04b\n", tlp.last_be)};
            
            if (tlp.payload_data.size() > 0) begin
                report_str = {report_str, $sformatf("  Payload Size  : %0d DW\n", tlp.payload_data.size())};
                report_str = {report_str, "  Payload Data  : {"};
                
                for (int j = 0; j < tlp.payload_data.size(); j++) begin
                    if (j > 0) report_str = {report_str, ", "};
                    if (j % 4 == 0 && j > 0) report_str = {report_str, "\n                   "};
                    report_str = {report_str, $sformatf("0x%08h", tlp.payload_data[j])};
                end
                
                report_str = {report_str, "}\n"};
            end
            else begin
                report_str = {report_str, "  Payload Size  : 0 (No data)\n"};
            end
            
            report_str = {report_str, "\n"};
        end
    end
    
    //------------------------------------------------------------------
    // Unmatched User Commands Report
    //------------------------------------------------------------------
    
    if (expected_user.size() > 0) begin
        report_str = {report_str, "========================================================================\n"};
        report_str = {report_str, "                    UNMATCHED USER COMMANDS                            \n"};
        report_str = {report_str, "========================================================================\n\n"};
        
        foreach (expected_user[i]) begin
            tl_user_seq_item user = expected_user[i];
            
            report_str = {report_str, $sformatf("--- Unmatched User Cmd #%0d ---\n", i+1)};
            report_str = {report_str, $sformatf("  Transaction   : %s %s\n", 
                user.trans_type.name(),
                user.is_write ? "Write" : "Read")};
            report_str = {report_str, $sformatf("  Address       : 0x%016h\n", user.addr)};
            report_str = {report_str, $sformatf("  Length        : %0d DW\n", user.length_dw)};
            
            if (user.trans_type == CMD_CFG) begin
                report_str = {report_str, $sformatf("  Config Target : Bus=%0d Dev=%0d Func=%0d Reg=%0d\n",
                    user.bus, user.device, user.function_num, user.reg_num)};
            end
            
            if (user.is_write && user.data_payload.size() > 0) begin
                report_str = {report_str, "  Write Data    : {"};
                
                for (int j = 0; j < user.data_payload.size(); j++) begin
                    if (j > 0) report_str = {report_str, ", "};
                    if (j % 4 == 0 && j > 0) report_str = {report_str, "\n                   "};
                    report_str = {report_str, $sformatf("0x%08h", user.data_payload[j])};
                end
                
                report_str = {report_str, "}\n"};
            end
            
            report_str = {report_str, "\n"};
        end
    end
    
    //------------------------------------------------------------------
    // Footer
    //------------------------------------------------------------------
    
    report_str = {report_str, "========================================================================\n"};
    report_str = {report_str, "                         END OF REPORT                                 \n"};
    report_str = {report_str, "========================================================================\n"};
    
    //------------------------------------------------------------------
    // Print Report
    //------------------------------------------------------------------
    
    if (num_mismatches == 0 && expected_user.size() == 0) begin
        `uvm_info("TX_SCOREBOARD", report_str, UVM_LOW)
    end
    else begin
        `uvm_error("TX_SCOREBOARD", report_str)
    end
    
endfunction : report_phase

//------------------------------------------------------------------
// Helper Function: Get Format String
//------------------------------------------------------------------

function string get_fmt_str(bit [2:0] fmt);
    case (fmt)
        3'b000: return "3DW no data";
        3'b001: return "4DW no data";
        3'b010: return "3DW with data";
        3'b011: return "4DW with data";
        default: return "Reserved";
    endcase
endfunction : get_fmt_str
endclass : tx_scoreboard

`endif
