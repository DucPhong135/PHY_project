

class rx_seq extends uvm_sequence #(tl_tlp_seq_item);
  
  `uvm_object_utils(rx_seq)

  int num_transactions = 5;

  rx_memory_seq mem_memory_seq;
  
  function new(string name = "rx_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction
  
  virtual task body();
  `uvm_do(mem_memory_seq);
  endtask: body

endclass: rx_seq