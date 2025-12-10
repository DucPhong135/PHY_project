// mem_monitor.sv
class mem_monitor extends uvm_monitor;
  `uvm_component_utils(mem_monitor)
  
  virtual mem_if vif;
  uvm_analysis_port #(mem_sequence_item) mem_ap;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
    mem_ap = new("mem_ap", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal("NO_VIF", "Virtual interface not found")
  endfunction
  
  task run_phase(uvm_phase phase);
    `uvm_info(get_type_name(), "Memory monitor started", UVM_LOW)
    fork
      monitor_transactions();
    join
  endtask
  
  // task monitor_writes();
  //   mem_sequence_item txn;
  //   int total_beats;
  //   forever begin
      
  //     if (vif.memwr_req_valid && vif.memwr_req_ready) begin
  //       `uvm_info("MEM_MON", "Detected memory write request", UVM_LOW)
  //       txn = mem_sequence_item::type_id::create("txn");
  //       txn.is_write = 1'b1;
  //       txn.addr = vif.memwr_req.addr;
  //       txn.length = vif.memwr_req.length;
  //       txn.first_be = vif.memwr_req.first_be;
  //       txn.last_be = vif.memwr_req.last_be;
        
  //       // Collect data beats
  //       total_beats = (txn.length + 3) / 4;
  //       for (int i = 0; i < total_beats; i++) begin
  //         @(posedge vif.clk);
  //         while (!(vif.memwr_data_valid && vif.memwr_data_ready))
  //           @(posedge vif.clk);
  //         txn.data_queue.push_back(vif.memwr_data);
  //         `uvm_info("MEM_MON", $sformatf("Captured write data beat %0d: 0x%0h", i, vif.memwr_data), UVM_LOW)
  //       end
        
  //       for (int i = 0; i < total_beats; i++) begin
  //         bit[127:0] data_beat = txn.data_queue[i];
  //         txn.payload_data.push_back(data_beat[31:0]);
  //         txn.payload_data.push_back(data_beat[63:32]);
  //         txn.payload_data.push_back(data_beat[95:64]);
  //         txn.payload_data.push_back(data_beat[127:96]);
  //       end
  //       `uvm_info("MEM_MON", $sformatf("WR: Addr=0x%0h, Len=%0d, Beats=%0d",
  //                 txn.addr, txn.length, txn.data_queue.size()), UVM_LOW )
        
  //       mem_ap.write(txn);  // Send to scoreboard
  //     end
  //     @(posedge vif.clk);
  //   end
  // endtask
  
  // task monitor_reads();
  //   mem_sequence_item txn;
  //   int total_beats;
  //   forever begin     
  //     if (vif.memrd_req_valid && vif.memrd_req_ready) begin
  //       txn = mem_sequence_item::type_id::create("txn");
  //       txn.is_write = 1'b0;
  //       txn.addr = vif.memrd_req.addr;
  //       txn.length = vif.memrd_req.length;
  //       txn.first_be = vif.memrd_req.first_be;
  //       txn.last_be = vif.memrd_req.last_be;
        
  //       // Collect response data
  //       total_beats = (txn.length + 3) / 4;
  //       for (int i = 0; i < total_beats; i++) begin
  //         @(posedge vif.clk);
  //         while (!(vif.memrd_data_valid && vif.memrd_data_ready))
  //           @(posedge vif.clk);
  //         txn.data_queue.push_back(vif.memrd_data);
  //       end
        
  //       for (int i = 0; i < total_beats; i++) begin
  //         bit[127:0] data_beat = txn.data_queue[i];
  //         txn.payload_data.push_back(data_beat[31:0]);
  //         txn.payload_data.push_back(data_beat[63:32]);
  //         txn.payload_data.push_back(data_beat[95:64]);
  //         txn.payload_data.push_back(data_beat[127:96]);
  //       end

  //       `uvm_info("MEM_MON", $sformatf("RD: Addr=0x%0h, Len=%0d, Beats=%0d",
  //                 txn.addr, txn.length, txn.data_queue.size()), UVM_MEDIUM)
        
  //       mem_ap.write(txn);  // Send to scoreboard
  //     end
  //     @(posedge vif.clk);
  //   end
  // endtask

  task monitor_transactions();
    mem_sequence_item txn;
    int total_beats;
    forever begin
      // Sample signals on clock edge to avoid missing transactions
      @(posedge vif.clk);
      
      if(vif.memrd_req_valid && vif.memrd_req_ready) begin
        txn = mem_sequence_item::type_id::create("txn");
        txn.is_write = 1'b0;
        txn.addr = vif.memrd_req.addr;
        txn.length = vif.memrd_req.length;
        txn.first_be = vif.memrd_req.first_be;
        txn.last_be = vif.memrd_req.last_be;
        
        // Collect response data
        total_beats = (txn.length + 3) / 4;
        for (int i = 0; i < total_beats; i++) begin
          @(posedge vif.clk);
          while (!(vif.memrd_data_valid && vif.memrd_data_ready))
            @(posedge vif.clk);
          txn.data_queue.push_back(vif.memrd_data);
        end
        
        for (int i = 0; i < total_beats; i++) begin
          bit[127:0] data_beat = txn.data_queue[i];
          txn.payload_data.push_back(data_beat[31:0]);
          txn.payload_data.push_back(data_beat[63:32]);
          txn.payload_data.push_back(data_beat[95:64]);
          txn.payload_data.push_back(data_beat[127:96]);
        end

        `uvm_info("MEM_MON", $sformatf("RD: Addr=0x%0h, Len=%0d, Beats=%0d",
                  txn.addr, txn.length, txn.data_queue.size()), UVM_MEDIUM)
        
        mem_ap.write(txn);  // Send to scoreboard
      end
      else if(vif.memwr_req_valid && vif.memwr_req_ready) begin
        `uvm_info("MEM_MON", "Detected memory write request", UVM_LOW)
        txn = mem_sequence_item::type_id::create("txn");
        txn.is_write = 1'b1;
        txn.addr = vif.memwr_req.addr;
        txn.length = vif.memwr_req.length;
        txn.first_be = vif.memwr_req.first_be;
        txn.last_be = vif.memwr_req.last_be;
        
        // Collect data beats
        total_beats = (txn.length + 3) / 4;
        for (int i = 0; i < total_beats; i++) begin
          @(posedge vif.clk);
          while (!(vif.memwr_data_valid && vif.memwr_data_ready))
            @(posedge vif.clk);
          txn.data_queue.push_back(vif.memwr_data);
          `uvm_info("MEM_MON", $sformatf("Captured write data beat %0d: 0x%0h", i, vif.memwr_data), UVM_LOW)
        end
        
        for (int i = 0; i < total_beats; i++) begin
          bit[127:0] data_beat = txn.data_queue[i];
          txn.payload_data.push_back(data_beat[31:0]);
          txn.payload_data.push_back(data_beat[63:32]);
          txn.payload_data.push_back(data_beat[95:64]);
          txn.payload_data.push_back(data_beat[127:96]);
        end
        `uvm_info("MEM_MON", $sformatf("WR: Addr=0x%0h, Len=%0d, Beats=%0d",
                  txn.addr, txn.length, txn.data_queue.size()), UVM_LOW )
        
        mem_ap.write(txn);  // Send to scoreboard
      end
    end
  endtask
  
endclass