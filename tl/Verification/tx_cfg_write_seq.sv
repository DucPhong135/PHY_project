`ifndef TX_CFG_WRITE_SEQ_SV
`define TX_CFG_WRITE_SEQ_SV


class tx_cfg_write_seq extends uvm_sequence #(tl_user_seq_item);

  `uvm_object_utils(tx_cfg_write_seq)

  int num_transactions = 30;

  function new(string name = "tx_cfg_write_seq");
    super.new(name);
  endfunction : new


  virtual task body();
    repeat (num_transactions) begin
        `uvm_do_with(req, {
            trans_type == CMD_CFG;
            is_write == 1'b1;
            bus == 8'b0;
            length_dw == 1;
            }
        );    
    end
  endtask : body

endclass : tx_cfg_write_seq
`endif // TX_CFG_WRITE_SEQ_SV