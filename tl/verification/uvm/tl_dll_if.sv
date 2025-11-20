`ifndef TL_DLL_IF_SV
`define TL_DLL_IF_SV


interface tl_dll_if (
    input logic clk,
    input logic rst_n
);

tl_stream_t tl_tx_o;
logic tl_tx_valid_o;
logic tl_tx_ready_i;

tl_stream_t tl_rx_i;
logic tl_rx_valid_i;
logic tl_rx_ready_o;

fc_update_t fc_update_i;
logic fc_valid_i;

  task automatic capture_tx_tlp(output tl_stream_t beats[$]);
    beats.delete();
    
    // Wait for start of packet
    @(posedge clk);
    while (!(tl_tx_valid_o && tl_tx_ready_i && tl_tx_o.sop)) begin
      @(posedge clk);
    end
    
    // Capture packet beats
    do begin
      if (tl_tx_valid_o && tl_tx_ready_i) begin
        beats.push_back(tl_tx_o);
      end
      @(posedge clk);
    end while (!tl_tx_o.eop || !tl_tx_valid_o || !tl_tx_ready_i);
  endtask


  task send_rx_tlp(tl_stream_t beats[$]);
    foreach (beats[i]) begin
      @(posedge clk);
      tl_rx_i       <= beats[i];
      tl_rx_valid_i <= 1'b1;
      
      while (!tl_rx_ready_o) @(posedge clk);
    end
    
    @(posedge clk);
    tl_rx_valid_i <= 1'b0;
  endtask


  task send_fc_update(bit [1:0] vc, bit [1:0] fc_type, bit [11:0] credits);
    @(posedge clk);
    fc_update_i.vc      <= vc;
    fc_update_i.fc_type <= fc_type;
    fc_update_i.credits <= credits;
    fc_valid_i          <= 1'b1;
    
    @(posedge clk);
    fc_valid_i <= 1'b0;
  endtask


  task init_signals();
    tl_tx_ready_i <= 1'b1;  // Always ready to accept TX
    tl_rx_i       <= '0;
    tl_rx_valid_i <= 1'b0;
    fc_update_i   <= '0;
    fc_valid_i    <= 1'b0;
  endtask

endinterface : tl_dll_if

