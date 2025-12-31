`ifndef tx_mem_write_seq_SV
`define tx_mem_write_seq_SV

class tx_mem_write_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_mem_write_seq)

   int num_transactions = 5;

  // Constructor
  function new(string name = "tx_mem_write_seq");
    super.new(name);
    set_automatic_phase_objection(1);
  endfunction

  // Body task: generate memory write transactions with specific patterns
  virtual task body();

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b1;
        length_dw inside {[4:8]}; // Length between 4 and 8 DW
        addr[1:0] == 2'b00;       // Aligned address
        addr[63:32] != 32'h0000_0000; // High address space
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_HIGH)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b1;
        length_dw inside {[1:8]};
        addr[1:0] != 2'b00;       // Misaligned address
        addr[63:32] != 32'h0000_0000; // High address space
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_HIGH)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b1;
        length_dw inside {[4:8]};
        addr[1:0] == 2'b00;       // Aligned address
        addr[63:32] == 32'h0000_0000; // Low address space
        });
        `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                    req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_HIGH)
    end

    repeat (num_transactions) begin
      `uvm_do_with(req, {
        trans_type == tl_pkg::CMD_MEM;
        is_write == 1'b1;
        length_dw inside {[4:8]};
        addr[1:0] != 2'b00;       // Misaligned address
        addr[63:32] == 32'h0000_0000; // Low address space
      });
      `uvm_info("TX_SEQ", $sformatf("Sent packet: Addr=0x%0h, Write = %0b, Len=%0d DW, Data[0]=0x%0h",
                req.addr, req.is_write, req.length_dw, req.data_payload[0]), UVM_HIGH)
    end
    endtask : body


endclass : tx_mem_write_seq
`endif // tx_mem_write_seq_SV