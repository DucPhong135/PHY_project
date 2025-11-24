`ifndef TX_SEQ_SV
`define TX_SEQ_SV



class tx_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_seq)

  // Configuration
  int num_transactions = 10;
  
  // constraint num_trans_c {
  //   num_transactions inside {[5:7]};
  // }

  function new(string name = "tx_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  virtual task body();
    tl_user_seq_item tx_item;

    `uvm_info("TX_SEQ", $sformatf("Starting sequence with %0d transactions", 
              num_transactions),
              UVM_LOW)

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write   == 1'b0;           // Memory write
        length_dw  inside {[1:16]};   // Small transfers
      });

      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    end
  endtask

endclass : tx_seq

`endif // TX_SEQ_SV