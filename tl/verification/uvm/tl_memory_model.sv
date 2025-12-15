`ifndef tl_memory_model_sv
`define tl_memory_model_sv
import tl_pkg::*;

class tl_memory_model extends uvm_component;
  `uvm_component_utils(tl_memory_model)
  
  // Virtual interface handle
  virtual mem_if vif;
  
  // Memory storage backend
  mem_storage storage;

  uvm_analysis_port#(mem_sequence_item) mem_ap;
  
  // Constructor
  function new(string name, uvm_component parent);
    super.new(name, parent);
    storage = new();
    mem_ap = new("mem_ap", this);
  endfunction
  
  // Build phase - get virtual interface from config DB
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if (!uvm_config_db#(virtual mem_if)::get(this, "", "mem_vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found in config DB")
  endfunction
  
  // Run phase - main functionality
  task run_phase(uvm_phase phase);
    

    vif.init_signals();
    // Wait for reset
    @(negedge vif.rst_n);
    @(posedge vif.rst_n);
    
    `uvm_info(get_type_name(), "Memory model started", UVM_MEDIUM)
    
    // Run concurrent tasks for write and read
    fork
      handle_request();
    join
    
  endtask
  
  //================================================================
  // WRITE HANDLER - Responds to write requests from DUT
  //================================================================
  // task handle_write_requests();
  //   bit[63:0] wr_addr;
  //   bit[9:0]  wr_length;
  //   bit[3:0]  wr_first_be, wr_last_be;
  //   int       wr_beat_count;
  //   int       total_beats;
    
  //   forever begin
  //     // Ready to accept write request
  //     vif.memwr_req_ready = 1'b1;
      
  //     @(posedge vif.clk);
      
  //     // Check for write request
  //     if (vif.memwr_req_valid && vif.memwr_req_ready) begin
        
  //       // Capture request metadata
  //       wr_addr     = vif.memwr_req.addr;
  //       wr_length   = vif.memwr_req.length;
  //       wr_first_be = vif.memwr_req.first_be;
  //       wr_last_be  = vif.memwr_req.last_be;
        
  //       total_beats = (wr_length + 3) / 4;  // Ceiling division
  //       wr_beat_count = 0;
        
  //       `uvm_info(get_type_name(), 
  //                 $sformatf("WR_REQ: Addr=0x%0h, Len=%0d DWs, Beats=%0d", 
  //                          wr_addr, wr_length, total_beats), UVM_MEDIUM)
        
  //       // Stop accepting new requests
  //       vif.memwr_req_ready = 1'b0;
        
  //       // Ready to accept write data
  //       vif.memwr_data_ready = 1'b1;
        
  //       // Collect all data beats
  //       while (wr_beat_count < total_beats) begin
  //         @(posedge vif.clk);
          
  //         if (vif.memwr_data_valid && vif.memwr_data_ready) begin
            
  //           // Calculate byte enables for this beat
  //           bit[15:0] be = storage.calc_beat_be(
  //             wr_beat_count, wr_length, wr_first_be, wr_last_be);
            
  //           // Write to memory
  //           storage.write(wr_addr, vif.memwr_data, be);
            
  //           `uvm_info(get_type_name(),
  //                     $sformatf("WR_DATA[%0d]: Addr=0x%0h, Data=0x%032h, BE=0x%04h",
  //                              wr_beat_count, wr_addr, vif.memwr_data, be), UVM_HIGH)
            
  //           // Move to next beat
  //           wr_addr += 16;  // 16 bytes per beat
  //           wr_beat_count++;
  //         end
  //       end
        
  //       // Transaction complete
  //       vif.memwr_data_ready = 1'b0;
  //       `uvm_info(get_type_name(), "WR_COMPLETE", UVM_MEDIUM)
  //     end
  //   end
  // endtask
  
  // //================================================================
  // // READ HANDLER - Responds to read requests from DUT
  // //================================================================
  // task handle_read_requests();
  //   bit[63:0] rd_addr;
  //   bit[9:0]  rd_length;
  //   bit[3:0]  rd_first_be, rd_last_be;
  //   int       rd_beat_count;
  //   int       total_beats;
  //   bit[127:0] rd_data;
    
  //   forever begin
  //     // Ready to accept read request
  //     vif.memrd_req_ready = 1'b1;
  //     vif.memrd_data_valid = 1'b0;
      
  //     @(posedge vif.clk);
      
  //     // Check for read request
  //     if (vif.memrd_req_valid && vif.memrd_req_ready) begin
        
  //       // Capture request metadata
  //       rd_addr     = vif.memrd_req.addr;
  //       rd_length   = vif.memrd_req.length;
  //       rd_first_be = vif.memrd_req.first_be;
  //       rd_last_be  = vif.memrd_req.last_be;
        
  //       total_beats = (rd_length + 3) / 4;
  //       rd_beat_count = 0;
        
  //       `uvm_info(get_type_name(),
  //                 $sformatf("RD_REQ: Addr=0x%0h, Len=%0d DWs, Beats=%0d",
  //                          rd_addr, rd_length, total_beats), UVM_MEDIUM)
        
  //       // Stop accepting new requests
  //       vif.memrd_req_ready = 1'b0;
        
  //       // Send all data beats
  //       while (rd_beat_count < total_beats) begin
  //         @(posedge vif.clk);
          
  //         // Wait until DUT is ready or we haven't sent data yet
  //         if (vif.memrd_data_ready) begin

  //           // Calculate byte enables for this beat
  //           bit[15:0] be = storage.calc_beat_be(
  //             rd_beat_count, rd_length, rd_first_be, rd_last_be);
            
  //           // Read from memory
  //           rd_data = storage.read(rd_addr, be);
            
  //           // Drive onto interface
  //           vif.memrd_data = rd_data;
  //           vif.memrd_data_valid = 1'b1;
            
  //           `uvm_info(get_type_name(),
  //                     $sformatf("RD_DATA[%0d]: Addr=0x%0h, Data=0x%032h",
  //                              rd_beat_count, rd_addr, rd_data), UVM_HIGH)
            
  //           // Move to next beat
  //           rd_addr += 16;
  //           rd_beat_count++;
  //         end
  //       end
        
  //       // Wait for last beat to be consumed
  //       @(posedge vif.clk);
  //       while (!vif.memrd_data_ready) @(posedge vif.clk);
        
  //       // Transaction complete
  //       vif.memrd_data_valid = 1'b0;
  //       `uvm_info(get_type_name(), "RD_COMPLETE", UVM_MEDIUM)
  //     end
  //   end
  // endtask

  task handle_request();
    bit[63:0] wr_addr;
    bit[9:0]  wr_length;
    bit[3:0]  wr_first_be, wr_last_be;
    int       wr_beat_count;
    int       total_beats;

    bit[63:0] rd_addr;
    bit[9:0]  rd_length;
    bit[3:0]  rd_first_be, rd_last_be;
    int       rd_beat_count;
    bit[127:0] rd_data;

    mem_sequence_item txn;

    forever begin
      vif.memwr_req_ready = 1'b1;
      vif.memrd_req_ready = 1'b1;

      @(posedge vif.clk);
      if(vif.memrd_req_valid && vif.memrd_req_ready) begin

        txn = mem_sequence_item::type_id::create("rd_txn");

        rd_addr     = vif.memrd_req.addr;
        rd_length   = vif.memrd_req.length;
        rd_first_be = vif.memrd_req.first_be;
        rd_last_be  = vif.memrd_req.last_be;
        
        txn.is_write = 1'b0;
        txn.addr     = rd_addr;
        txn.length   = rd_length;
        txn.first_be = rd_first_be;
        txn.last_be  = rd_last_be;
        
        total_beats = (rd_length + 3) / 4;
        rd_beat_count = 0;
        
        `uvm_info(get_type_name(),
                  $sformatf("RD_REQ: Addr=0x%0h, Len=%0d DWs, Beats=%0d",
                           rd_addr, rd_length, total_beats), UVM_MEDIUM)
        
        // Stop accepting new requests
        vif.memrd_req_ready = 1'b0;
        vif.memwr_req_ready = 1'b0;
        
        // Send all data beats
        while (rd_beat_count < total_beats) begin
          @(posedge vif.clk);
          
          // Wait until DUT is ready or we haven't sent data yet
          if (vif.memrd_data_ready) begin

            // Calculate byte enables for this beat
            bit[15:0] be = storage.calc_beat_be(
              rd_beat_count, rd_length, rd_first_be, rd_last_be);
            
            // Read from memory
            rd_data = storage.read(rd_addr, be);
            
            // Drive onto interface
            vif.memrd_data = rd_data;
            vif.memrd_data_valid = 1'b1;

            txn.data_queue.push_back(rd_data);

            for (int dw = 0; dw < 4; dw++) begin
              if (rd_beat_count * 4 + dw < rd_length) begin
                txn.payload_data.push_back(rd_data[dw*32 +: 32]);
              end
            end
            
            `uvm_info(get_type_name(),
                      $sformatf("RD_DATA[%0d]: Addr=0x%0h, Data=0x%032h",
                               rd_beat_count, rd_addr, rd_data), UVM_HIGH)
            
            // Move to next beat
            rd_addr += 16;
            rd_beat_count++;
          end
        end
        
        // Wait for last beat to be consumed
        @(posedge vif.clk);
        while (!vif.memrd_data_ready) @(posedge vif.clk);
        
        // Transaction complete
        vif.memrd_data_valid = 1'b0;
        `uvm_info(get_type_name(), "print rd_txn", UVM_MEDIUM)
        txn.print();
        mem_ap.write(txn);  // Send to scoreboard
        `uvm_info(get_type_name(), "RD_COMPLETE", UVM_MEDIUM)
      end

      else if (vif.memwr_req_valid && vif.memwr_req_ready) begin
         txn = mem_sequence_item::type_id::create("wr_txn");

        wr_addr     = vif.memwr_req.addr;
        wr_length   = vif.memwr_req.length;
        wr_first_be = vif.memwr_req.first_be;
        wr_last_be  = vif.memwr_req.last_be;

        txn.is_write = 1'b1;
        txn.addr = wr_addr;
        txn.length = wr_length;
        txn.first_be = wr_first_be;
        txn.last_be = wr_last_be;
        
        total_beats = (wr_length + 3) / 4;  // Ceiling division
        wr_beat_count = 0;
        
        `uvm_info(get_type_name(), 
                  $sformatf("WR_REQ: Addr=0x%0h, Len=%0d DWs, Beats=%0d", 
                           wr_addr, wr_length, total_beats), UVM_MEDIUM)
        
        // Stop accepting new requests
        vif.memwr_req_ready = 1'b0;
        vif.memrd_req_ready = 1'b0;
        
        // Ready to accept write data
        vif.memwr_data_ready = 1'b1;
        
        // Collect all data beats
        while (wr_beat_count < total_beats) begin
          @(posedge vif.clk);
          
          if (vif.memwr_data_valid && vif.memwr_data_ready) begin
            
            // Calculate byte enables for this beat
            bit[15:0] be = storage.calc_beat_be(
              wr_beat_count, wr_length, wr_first_be, wr_last_be);
            
            // Write to memory
            storage.write(wr_addr, vif.memwr_data, be);

            txn.data_queue.push_back(vif.memwr_data);

            for (int dw = 0; dw < 4; dw++) begin
              if (wr_beat_count * 4 + dw < wr_length) begin
                txn.payload_data.push_back(vif.memwr_data[dw*32 +: 32]);
              end
            end
            
            `uvm_info(get_type_name(),
                      $sformatf("WR_DATA[%0d]: Addr=0x%0h, Data=0x%032h, BE=0x%04h",
                               wr_beat_count, wr_addr, vif.memwr_data, be), UVM_HIGH)
            
            // Move to next beat
            wr_addr += 16;  // 16 bytes per beat
            wr_beat_count++;
          end
        end
        
        // Transaction complete
        vif.memwr_data_ready = 1'b0;
        `uvm_info(get_type_name(), "print wr_txn", UVM_MEDIUM)
        txn.print();
        mem_ap.write(txn);

        `uvm_info(get_type_name(), "WR_COMPLETE", UVM_MEDIUM)
      end
    end
  endtask

  
  //================================================================
  // UTILITY FUNCTIONS
  //================================================================
  
  // Preload memory for testing
  function void preload(bit[63:0] addr, bit[127:0] data_queue[$]);
    foreach (data_queue[i]) begin
      storage.write(addr + i*16, data_queue[i], 16'hFFFF);
    end
    `uvm_info(get_type_name(), 
              $sformatf("Preloaded %0d beats at 0x%0h", data_queue.size(), addr), 
              UVM_LOW)
  endfunction
  
  // Dump memory for debugging
  function void dump(bit[63:0] addr, int num_bytes);
    for (int i = 0; i < num_bytes; i++) begin
      if (i % 16 == 0) $write("0x%08h: ", addr + i);
      if (storage.mem.exists(addr + i))
        $write("%02h ", storage.mem[addr + i]);
      else
        $write("-- ");
      if (i % 16 == 15) $display("");
    end
  endfunction
  
endclass

`endif // tl_memory_model