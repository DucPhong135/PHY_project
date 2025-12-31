`ifndef TL_DLL_MONITOR_SV
`define TL_DLL_MONITOR_SV


class tl_dll_monitor extends uvm_monitor;
  
  `uvm_component_utils(tl_dll_monitor)

  bit monitor_cpl = 1'b0;

  int pkt_received_count = 0;
  int pkt_sent_count = 0;
  
  virtual tl_dll_if vif;
  uvm_analysis_port #(tl_tlp_seq_item) tx_monitor_ap;
  uvm_analysis_port #(tl_tlp_seq_item) rx_monitor_ap;

  tl_dll_sequencer reactive_sqr;

  function new(string name = "tl_dll_monitor", uvm_component parent = null);
    super.new(name, parent);
    tx_monitor_ap = new("tx_monitor_ap", this);
    rx_monitor_ap = new("rx_monitor_ap", this);
    if(uvm_config_db#(bit)::get(this, "", "monitor_cpl", monitor_cpl)) begin
        `uvm_info("DLL_MON", $sformatf("DLL Monitor configured to monitor completions: %0d", monitor_cpl), UVM_LOW);
    end
    else begin
        `uvm_info("DLL_MON", "DLL Monitor using default monitor_cpl = 0", UVM_LOW);
    end
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual tl_dll_if)::get(this, "", "dll_vif", vif)) begin
      `uvm_fatal("DLL_MON", "Virtual interface not found")
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (monitor_cpl) begin
      if (reactive_sqr == null) begin
        `uvm_fatal("DLL_MON", "reactive_sqr is NULL! Connection not established.")
      end
      else begin
      `uvm_info("DLL_MON", 
                $sformatf("reactive_sqr successfully connected: %s", 
                         reactive_sqr.get_full_name()), 
                UVM_LOW)
      end
    end
  endfunction


  task run_phase(uvm_phase phase);

    fork
      monitor_tx();
      monitor_rx();
    join_none
  endtask
  
  // Monitor TX path (DUT -> Monitor)
  task monitor_tx();
    tl_tlp_seq_item tlp;
    tl_tlp_seq_item req_copy;
    
    forever begin
      @(posedge vif.clk);
      vif.tl_tx_ready_i <= 1'b1;
      if (vif.tl_tx_valid_o && vif.tl_tx_ready_i) begin
        
        if (vif.tl_tx_o.sop) begin
          tlp = tl_tlp_seq_item::type_id::create("tlp_tx");
        end
        
        if (tlp != null) begin
          tlp.parse_from_stream(vif.tl_tx_o);
        end
        
        if (vif.tl_tx_o.eop && tlp != null) begin

          pkt_received_count++;
          `uvm_info("TX_DLL_MON", $sformatf("TX Pkt#: %0d", pkt_received_count), UVM_HIGH);
          if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "TX_DLL_MON")) begin
            tlp.print();
          end

          tx_monitor_ap.write(tlp);

          if(monitor_cpl) begin
            if(tlp.need_cpl()) begin
              `uvm_info("TX_DLL_MON", $sformatf("Send request for completion: pkt_type = %0d, fmt = %0d", tlp.pkt_type, tlp.fmt), UVM_HIGH);
              $cast(req_copy, tlp.clone());
              reactive_sqr.put_request(req_copy);
            end
          end
          tlp = null;
        end
      end
    end
  endtask
  
  // Monitor RX path (Driver -> DUT)
  task monitor_rx();
    tl_tlp_seq_item tlp;
    
    forever begin
      @(posedge vif.clk);
      if (vif.tl_rx_valid_i && vif.tl_rx_ready_o) begin
        
        if (vif.tl_rx_i.sop) begin
          tlp = tl_tlp_seq_item::type_id::create("tlp_rx");
        end
        
        if (tlp != null) begin
          tlp.parse_from_stream(vif.tl_rx_i);
        end
        
        if (vif.tl_rx_i.eop && tlp != null) begin
          pkt_sent_count++;
          `uvm_info("RX_DLL_MON", $sformatf("RX Pkt#: %0d", pkt_sent_count), UVM_HIGH);

          if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "RX_DLL_MON")) begin
            tlp.print();
          end

          rx_monitor_ap.write(tlp);
          tlp = null;
        end
      end
    end
  endtask
  
endclass : tl_dll_monitor

`endif