`ifndef TL_DLL_IF_SV
`define TL_DLL_IF_SV



interface tl_dll_if (
    input logic clk,
    input logic rst_n
);

  import tl_pkg::*;


tl_stream_t tl_tx_o;
logic tl_tx_valid_o;
logic tl_tx_ready_i;

tl_stream_t tl_rx_i;
logic tl_rx_valid_i;
logic tl_rx_ready_o;

tl_credit_t fc_update_i;
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


//------------------------------------------------------------------
// Driver Task: Send Flow Control Update
// Uses tl_credit_t structure with 6 credit types
//------------------------------------------------------------------
task send_fc_update(
  input logic [11:0] ph_credits,
  input logic [11:0] pd_credits,
  input logic [7:0]  nph_credits,
  input logic [11:0] npd_credits,
  input logic [7:0]  cplh_credits,
  input logic [11:0] cpld_credits
);
  @(posedge clk);
  
  // Assign all credit fields
  fc_update_i.ph_credits   <= ph_credits;
  fc_update_i.pd_credits   <= pd_credits;
  fc_update_i.nph_credits  <= nph_credits;
  fc_update_i.npd_credits  <= npd_credits;
  fc_update_i.cplh_credits <= cplh_credits;
  fc_update_i.cpld_credits <= cpld_credits;
  
  fc_valid_i <= 1'b1;
  
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


  task drive_tlp_packet(tl_stream_t beats[$]);
    foreach (beats[i]) begin
      // Wait for ready before asserting valid
      @(posedge clk);
      while (!tl_rx_ready_o) begin
        @(posedge clk);
      end
      
      // Drive beat and assert valid only when ready is high
      tl_rx_i       <= beats[i];
      tl_rx_valid_i <= 1'b1;
      
      
      // Hold for one cycle (valid & ready both high = transfer)
      @(posedge clk);
      tl_rx_valid_i <= 1'b0;
    end
    
    // De-assert valid after last beat
    @(posedge clk);
    tl_rx_valid_i <= 1'b0;
  endtask

endinterface : tl_dll_if

`endif