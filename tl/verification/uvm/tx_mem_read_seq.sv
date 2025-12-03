`ifndef tx_mem_read_seq_SV
`define tx_mem_read_seq_SV

class tx_mem_read_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_mem_read_seq)

  int num_transactions = 5;

  // Constructor
  function new(string name = "tx_mem_read_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  // Body task: define the sequence of memory read transactions
  virtual task body();
    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write   == 1'b0;           // Memory read
        length_dw  inside {[1:16]};   // Small transfers
        addr[1:0] == 2'b00;          // Aligned address
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b0;
        length_dw inside {[1:16]};
        addr[1:0] != 2'b00;  // Misaligned address
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b0;
        length_dw inside {[1:16]};
        addr[1:0] == 2'b00;          // Aligned address
        addr[63:32] == 32'h0000_0000; // High address space
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b0;
        length_dw inside {[1:16]};
        addr[1:0] != 2'b00;
        addr[63:32] == 32'h0000_0000;
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_LOW)
    end
  endtask : body
endclass : tx_mem_read_seq

`endif // tx_mem_read_seq_SV