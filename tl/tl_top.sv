`timescale 1ns/1ps
`default_nettype none
import tl_pkg::*;      // bring in the typedefs

module tl_top #(
  parameter int TAG_W = 8
)(
  // --- clocks / reset
  input  logic       clk,
  input  logic       rst_n,

  // --- DLL side
  output tl_stream_t tl_tx,
  output logic       tl_tx_valid,
  input  logic       tl_tx_ready,

  input  tl_stream_t tl_rx,
  input  logic       tl_rx_valid,
  output logic       tl_rx_ready,

  input  tl_credit_t fc_update,
  input  logic       fc_valid,

  // --- User side
  input  tl_cmd_t    usr_cmd,
  input  logic       usr_cmd_valid,
  output logic       usr_cmd_ready,

  input  tl_data_t   usr_wdata,
  input  logic       usr_wvalid,
  output logic       usr_wready,

  output tl_data_t   usr_rdata,
  output logic       usr_rvalid,
  input  logic       usr_rready
);

  // -----------------------------------------------------------------
  // Wires between sub-blocks
  // -----------------------------------------------------------------
  logic [127:0]         hdr;
  logic                 hdr_valid, hdr_ready;
  logic                 is_posted, is_cpl;

  tl_stream_t           pkt_posted, pkt_np;
  logic                 pkt_posted_valid, pkt_posted_ready;
  logic                 pkt_np_valid,     pkt_np_ready;

  logic [TAG_W-1:0]     tag_alloc;
  logic                 tag_gnt;
  logic                 alloc_req;

  // -----------------------------------------------------------------
  // Sub-block instances
  // -----------------------------------------------------------------

  // Tag Table
  tl_tag_table #(.TAG_W(TAG_W)) u_tag_table (
    .clk             (clk),
    .rst_n           (rst_n),
    .alloc_req_i     (alloc_req),
    .alloc_tag_o     (tag_alloc),
    .alloc_gnt_o     (tag_gnt),
    // free path comes from cpl_engine
    .free_tag_i      ('0),
    .free_valid_i    (1'b0)
  );

  // Header Generator
  tl_hdr_gen u_hdr_gen (
    .clk            (clk),
    .rst_n          (rst_n),
    .cmd_i          (usr_cmd),
    .cmd_valid_i    (usr_cmd_valid),
    .cmd_ready_o    (usr_cmd_ready),
    .tag_i          (tag_alloc),
    .tag_valid_i    (tag_gnt),
    .tag_consume_o  (alloc_req),
    .credit_ok_i    (/* from credit_mgr */ 1'b1),
    .hdr_o          (hdr),
    .hdr_valid_o    (hdr_valid),
    .hdr_ready_i    (hdr_ready),
    .is_posted_o    (is_posted),
    .is_cpl_o       (is_cpl)
  );

  // Payload Mux
  tl_payload_mux u_payload_mux (
    .clk               (clk),
    .rst_n             (rst_n),
    .wdata_i           (usr_wdata),
    .wdata_valid_i     (usr_wvalid),
    .wdata_ready_o     (usr_wready),
    .hdr_valid_i       (hdr_valid),
    .hdr_ready_o       (hdr_ready),
    .tx_pkt_o          (/* to arbiter */ pkt_posted),
    .tx_pkt_valid_o    (pkt_posted_valid),
    .tx_pkt_ready_i    (pkt_posted_ready)
  );

  // Credit Manager
  tl_credit_mgr u_credit_mgr (
    .clk            (clk),
    .rst_n          (rst_n),
    .fc_update_i    (fc_update),
    .fc_valid_i     (fc_valid),
    .tx_posted_i    (pkt_posted_valid & pkt_posted_ready),
    .tx_non_posted_i(pkt_np_valid     & pkt_np_ready),
    .credit_ok_o    (/* to hdr_gen */)
  );

  // TX Arbiter
  tl_tx_arb u_tx_arb (
    .clk               (clk),
    .rst_n             (rst_n),
    .pkt_posted_i      (pkt_posted),
    .pkt_posted_valid_i(pkt_posted_valid),
    .pkt_posted_ready_o(pkt_posted_ready),
    .pkt_np_i          (pkt_np),
    .pkt_np_valid_i    (pkt_np_valid),
    .pkt_np_ready_o    (pkt_np_ready),
    .tl_tx_o           (tl_tx),
    .tl_tx_valid_o     (tl_tx_valid),
    .tl_tx_ready_i     (tl_tx_ready)
  );

  // RX Parser
  tl_rx_parser #(.TAG_W(TAG_W)) u_rx_parser (
    .clk            (clk),
    .rst_n          (rst_n),
    .tl_rx_i        (tl_rx),
    .tl_rx_valid_i  (tl_rx_valid),
    .tl_rx_ready_o  (tl_rx_ready),
    .memwr_o        (/* not wired yet */),
    .memwr_valid_o  (),
    .memwr_ready_i  (1'b1),
    .cpl_tag_o      (),
    .cpl_data_o     (),
    .cpl_valid_o    (),
    .cpl_ready_i    (1'b1)
  );

  // Completion Engine (stubbed)
  tl_cpl_engine #(.TAG_W(TAG_W)) u_cpl_engine (
    .clk           (clk),
    .rst_n         (rst_n),
    .cpl_tag_i     (),
    .cpl_data_i    (),
    .cpl_valid_i   (),
    .cpl_ready_o   (),
    .ort_rd_tag_o  (),
    .ort_rd_en_o   (),
    .usr_rdata_o   (usr_rdata),
    .usr_rvalid_o  (usr_rvalid),
    .usr_rready_i  (usr_rready)
  );

endmodule : tl_top
`default_nettype wire
