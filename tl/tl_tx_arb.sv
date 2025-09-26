module tl_tx_arb #(
  // ---------------- existing ----------------
  parameter int STREAM_W = 128,

  // ---------------- must match tl_credit_mgr ----------------
  parameter int PH_WIDTH   = 8,
  parameter int PD_WIDTH   = 12,
  parameter int NPH_WIDTH  = 8,
  parameter int NPD_WIDTH  = 12,
  parameter int CPLH_WIDTH = 8,
  parameter int CPLD_WIDTH = 12
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // ==========================================================
  // 1)  REQUEST QUEUES  (unchanged)
  // ==========================================================
  input  tl_pkg::tl_stream_t     pkt_posted_i,
  input  logic                   pkt_posted_valid_i,
  output logic                   pkt_posted_ready_o,

  input  tl_pkg::tl_stream_t     pkt_np_i,
  input  logic                   pkt_np_valid_i,
  output logic                   pkt_np_ready_o,

  // Completion queue (Cpl / CplD)
  input  tl_pkg::tl_stream_t     pkt_cpl_i,
  input  logic                   pkt_cpl_valid_i,
  output logic                   pkt_cpl_ready_o,


  // ==========================================================
  // 2)  CREDIT-MANAGER INTERFACE  (NEW)
  // ==========================================================
  // credit-availability flags  (one per pool)
  input  logic                   ph_credit_ok_i,
  input  logic                   pd_credit_ok_i,
  input  logic                   nph_credit_ok_i,
  input  logic                   npd_credit_ok_i,
  input  logic                   cplh_credit_ok_i,
  input  logic                   cpld_credit_ok_i,

  // consume-pulses: generated ONLY for the packet the arbiter launches
  output logic                   ph_consume_v_o,
  output logic [PH_WIDTH-1:0]    ph_consume_dw_o,

  output logic                   pd_consume_v_o,
  output logic [PD_WIDTH-1:0]    pd_consume_dw_o,

  output logic                   nph_consume_v_o,
  output logic [NPH_WIDTH-1:0]   nph_consume_dw_o,

  output logic                   npd_consume_v_o,
  output logic [NPD_WIDTH-1:0]   npd_consume_dw_o,

  output logic                   cplh_consume_v_o,
  output logic [CPLH_WIDTH-1:0]  cplh_consume_dw_o,

  output logic                   cpld_consume_v_o,
  output logic [CPLD_WIDTH-1:0]  cpld_consume_dw_o,

  // ==========================================================
  // 3)  ARBITRATED OUTPUT TO DATA-LINK LAYER  (unchanged)
  // ==========================================================
  output tl_pkg::tl_stream_t     tl_tx_o,
  output logic                   tl_tx_valid_o,
  input  logic                   tl_tx_ready_i
);

localparam int GRANT_CPL = 3'b001;
localparam int GRANT_NP  = 3'b010;
localparam int GRANT_P   = 3'b100;


typedef enum logic [1:0] {
  IDLE = 2'd0,
  HDR  = 2'd1,
  DATA = 2'd2
} fsm_e;

tl_stream_t current_pkt;
logic       current_pkt_valid;

fsm_e fsm, fsm_next;

logic [3:0] posted_count;
logic [3:0] np_count;

logic [2:0] grant_state;


// TODO: round-robin or priority
logic posted_eligible = ph_credit_ok_i && pkt_posted_valid_i && (!pkt_posted_i.data[126] || pd_credit_ok_i);
logic np_eligible     = nph_credit_ok_i && pkt_np_valid_i && (!pkt_np_i.data[126] || npd_credit_ok_i);
logic cpl_eligible    = cplh_credit_ok_i && pkt_cpl_valid_i && (!pkt_cpl_i.data[126] || cpld_credit_ok_i);

always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    fsm <= IDLE;
  end
  else begin
    fsm <= fsm_next;
  end
end


always



endmodule
