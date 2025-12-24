`ifndef TX_SEQ_SV
`define TX_SEQ_SV



class tx_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_seq)

  bit monitor_cpl = 1'b0;

  // Configuration
  int num_transactions = 5;
  
  // Constructor
  tx_mem_read_seq mem_read_seq;
  tx_mem_write_seq mem_write_seq;
  tx_cfg_read_seq cfg_read_seq;
  tx_cfg_write_seq cfg_write_seq;

  function new(string name = "tx_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  virtual task pre_body();
      if (!uvm_config_db#(bit)::get(null, get_full_name(), "monitor_cpl", monitor_cpl)) begin
      `uvm_info("TX_SEQ", "monitor_cpl not set, using default value", UVM_MEDIUM)
    end

    `uvm_info("TX_SEQ", $sformatf("Starting sequence with %0d transactions, monitor_cpl=%0d", 
              num_transactions, monitor_cpl),
              UVM_LOW);
  endtask : pre_body

  virtual task body();
    
    if(!monitor_cpl) begin
      `uvm_info("TX_SEQ", "Starting memory write sequence, monitor CPL disabled", UVM_LOW);
      `uvm_do(mem_write_seq);
    end
    `uvm_do(mem_read_seq);
    `uvm_do(cfg_read_seq);
    `uvm_do(cfg_write_seq);
  endtask

endclass : tx_seq

`endif // TX_SEQ_SV