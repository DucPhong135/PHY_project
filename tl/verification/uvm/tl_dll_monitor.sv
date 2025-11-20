`ifndef TL_DLL_MONITOR_SV
`define TL_DLL_MONITOR_SV



class tl_dll_monitor extends uvm_monitor;
  
  `uvm_component_utils(tl_dll_monitor)
  
  virtual tl_dll_if vif;  
  function new(string name = "tl_dll_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_dll_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("DLL_MON", "Virtual interface not found")
    end
  endfunction
  
  task run_phase(uvm_phase phase);
    tl_tlp_seq_item tlp;
    
    forever begin
      @(posedge vif.clk);
      
      if (vif.tl_tx_valid_o && vif.tl_tx_ready_i) begin
        
        // Start new packet
        if (vif.tl_tx_o.sop) begin
          tlp = tl_tlp_seq_item::type_id::create("tlp");
          tlp.sop = 1'b1;
        end
        
        // Capture beat
        if (tlp != null) begin
          tlp.parse_from_stream(vif.tl_tx_o);
        end
        
        // End of packet
        if (vif.tl_tx_o.eop && tlp != null) begin
          tlp.eop = 1'b1;
          `uvm_info("DLL_MON", $sformatf("Captured TLP: %s, Addr=0x%0h, Len=%0d", 
                    tlp.get_type_str(), tlp.address, tlp.length), UVM_MEDIUM)
          tlp = null;
        end
      end
    end
  endtask
  
endclass : tl_dll_monitor

`endif // TL_DLL_MONITOR_SV