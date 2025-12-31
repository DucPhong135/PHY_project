`ifndef TL_DLL_DRIVER_SV
`define TL_DLL_DRIVER_SV

class tl_dll_driver extends uvm_driver #(tl_tlp_seq_item);

  `uvm_component_utils(tl_dll_driver)


  virtual tl_dll_if vif;

  // Constructor
  function new(string name = "tl_dll_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction


  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if(!uvm_config_db#(virtual tl_dll_if)::get(this, "", "dll_vif", vif)) begin
      `uvm_fatal("NOVIF", $sformatf("Virtual interface must be set for: %s.dll_vif", get_full_name()))
    end
  endfunction : build_phase


  task run_phase(uvm_phase phase);
    tl_tlp_seq_item txn;
    tl_stream_t beats[$];
    

    vif.init_signals();
    

    @(negedge vif.rst_n);
    @(posedge vif.rst_n);
    
    forever begin

      seq_item_port.get_next_item(txn);
      `uvm_info("DLL_DRV", "Received new TLP transaction from sequencer", UVM_HIGH);
      if (uvm_report_enabled(UVM_HIGH, UVM_INFO, "DLL_DRV")) begin
            txn.print();
      end

 
      txn.build_tlp_beats(txn, beats);
      

      vif.drive_tlp_packet(beats);
      

      seq_item_port.item_done();
    end
  endtask : run_phase
  
  
  

endclass : tl_dll_driver

`endif