`ifndef TX_CFG_READ_SEQ_SV
`define TX_CFG_READ_SEQ_SV


class tx_cfg_read_seq extends uvm_sequence #(tl_user_seq_item);

  int num_transactions = 10;


  `uvm_object_utils(tx_cfg_read_seq)

  // Constructor
  function new(string name = "tx_cfg_read_seq");
    super.new(name);
  endfunction : new

  // Body task
  virtual task body();
    repeat (num_transactions) begin
        `uvm_do_with(req, {
            trans_type == tl_pkg::CMD_CFG;
            is_write == 1'b0;
            bus == 8'b0;
            length_dw == 1;
        }
        );
    end
  endtask : body

endclass : tx_cfg_read_seq
`endif // TX_CFG_READ_SEQ_SV