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
  endtask

endclass : tx_seq

`endif // TX_SEQ_SV