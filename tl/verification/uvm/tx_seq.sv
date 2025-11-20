`ifndef TX_SEQ_SV
`define TX_SEQ_SV



class tx_seq extends uvm_sequence #(tl_cmd_seq_item);

  `uvm_object_utils(tx_seq)

  // Configuration
  rand int num_transactions;
  
  constraint num_trans_c {
    num_transactions inside {[1:10]};
  }

  function new(string name = "tx_seq");
    super.new(name);
  endfunction

  virtual task body();
    tl_cmd_seq_item tx_item;

    `uvm_info("TX_SEQ", $sformatf("Starting sequence with %0d transactions", 
              num_transactions), UVM_MEDIUM)

    repeat (num_transactions) begin
      // Create sequence item
      tx_item = tl_cmd_seq_item::type_id::create("tx_item");
      
      // Start transaction
      start_item(tx_item);
      
      // Randomize (includes both command and data)
      assert(tx_item.randomize() with {
        trans_type == tl_pkg::CMD_MEM;
        is_write   == 1'b1;           // Memory write
        length_dw  inside {[1:16]};   // Small transfers
      });
      
      // Finish transaction
      finish_item(tx_item);
      
      `uvm_info("TX_SEQ", $sformatf("Sent Write: Addr=0x%0h, Len=%0d DW, Data[0]=0x%0h",
                tx_item.addr, tx_item.length_dw, tx_item.data_payload[0]), UVM_HIGH)
    end
  endtask

endclass : tx_seq

`endif // TX_SEQ_SV