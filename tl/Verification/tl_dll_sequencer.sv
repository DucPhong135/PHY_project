`ifndef TL_DLL_SEQUENCER_SV
`define TL_DLL_SEQUENCER_SV

class tl_dll_sequencer extends uvm_sequencer#(tl_tlp_seq_item);

    `uvm_component_utils(tl_dll_sequencer)

    virtual tl_dll_if vif;

    bit monitor_cpl = 1'b1;

    mailbox #(tl_tlp_seq_item) request_mb;
    
    function new(string name = "tl_dll_sequencer", uvm_component parent = null);
        super.new(name, parent);
        if(monitor_cpl) begin
            `uvm_info("DLL_SEQR", "DLL Sequencer configured to monitor completions", UVM_LOW);
            request_mb = new();
            if(uvm_config_db#(virtual tl_dll_if)::get(this, "", "dll_vif", vif)) begin
                `uvm_info("DLL_SEQR", "DLL Sequencer obtained virtual interface", UVM_LOW);
            end
            else begin
                `uvm_fatal("DLL_SEQR", "Failed to get virtual interface for DLL Sequencer");
            end
        end
        else begin
            `uvm_info("DLL_SEQR", "DLL Sequencer NOT configured to monitor completions", UVM_LOW);
        end
    endfunction

    task put_request(input tl_tlp_seq_item req);
        request_mb.put(req);
        `uvm_info("DLL_SEQR", $sformatf("Request put into mailbox: %p", req), UVM_HIGH);
    endtask

    task get_request(output tl_tlp_seq_item req);
        request_mb.get(req);
        `uvm_info("DLL_SEQR", $sformatf("Request retrieved from mailbox: %p", req), UVM_HIGH);
    endtask

        function bit try_get_request(output tl_tlp_seq_item req);
        if (request_mb.try_get(req)) begin
            `uvm_info(get_type_name(), 
                      $sformatf("Got request: tag=%0d (remaining=%0d)", 
                               req.tag, request_mb.num()), 
                      UVM_HIGH)
            return 1;
        end
        return 0;
    endfunction
    
    function int num_pending_requests();
        return request_mb.num();
    endfunction
    
    function bit has_pending_requests();
        return (request_mb.num() > 0);
    endfunction
endclass : tl_dll_sequencer
`endif // TL_DLL_SEQUENCER_SV