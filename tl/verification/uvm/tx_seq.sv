`ifndef TX_SEQ_SV
`define TX_SEQ_SV



class tx_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_seq)

  // Configuration
  int num_transactions = 5;
  
  // Constructor
  tx_mem_read_seq mem_read_seq;
  tx_mem_write_seq mem_write_seq;
  tx_cfg_read_seq cfg_read_seq;
  tx_cfg_write_seq cfg_write_seq;

  function new(string name = "tx_seq");
    super.new(name);
    // mem_read_seq = tx_mem_read_seq::type_id::create("mem_read_seq");
    // mem_write_seq = tx_mem_write_seq::type_id::create("mem_write_seq");
    // mem_read_seq.num_transactions = num_transactions;
    // mem_write_seq.num_transactions = num_transactions;
    set_automatic_phase_objection(1);
  endfunction

  virtual task body();

    `uvm_info("TX_SEQ", $sformatf("Starting sequence with %0d transactions", 
              num_transactions),
              UVM_LOW)
    
    `uvm_do(mem_write_seq);
    `uvm_do(cfg_read_seq);
    `uvm_do(mem_read_seq);
    `uvm_do(cfg_write_seq);


    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write   == 1'b0;           // Memory read
    //     length_dw  inside {[1:16]};   // Small transfers
    //     addr[1:0] == 2'b00;          // Aligned address
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end

    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write == 1'b1;
    //     length_dw inside {[4:8]};
    //     addr[1:0] == 2'b00;
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end

    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write == 1'b0;
    //     length_dw inside {[1:16]};
    //     addr[1:0] != 2'b00;  // Misaligned address
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end

    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write == 1'b1;
    //     length_dw inside {[1:8]};
    //     addr[1:0] != 2'b00;
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end


    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write == 1'b0;
    //     length_dw inside {[1:16]};
    //     addr[1:0] != 2'b00;
    //     addr[63:32] == 32'h0000_0000;
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end

    // repeat (num_transactions) begin
    //   `uvm_do_with(req, {
    //     trans_type == tl_pkg::CMD_MEM;
    //     is_write == 1'b1;
    //     length_dw inside {[4:8]};
    //     addr[1:0] != 2'b00;
    //     addr[63:32] == 32'h0000_0000;
    //   });
    //   `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
    //             req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    // end
  endtask

endclass : tx_seq

`endif // TX_SEQ_SV