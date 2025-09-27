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

  input tl_pkg::tl_meta_t       pkt_posted_meta_i,
  input logic                   pkt_posted_meta_valid_i,
  output logic                  pkt_posted_meta_ready_o,

  input  tl_pkg::tl_stream_t     pkt_np_i,
  input  logic                   pkt_np_valid_i,
  output logic                   pkt_np_ready_o,

  input tl_pkg::tl_meta_t       pkt_np_meta_i,
  input logic                   pkt_np_meta_valid_i,
  output logic                  pkt_np_meta_ready_o,

  // Completion queue (Cpl / CplD)
  input  tl_pkg::tl_stream_t     pkt_cpl_i,
  input  logic                   pkt_cpl_valid_i,
  output logic                   pkt_cpl_ready_o,

  input tl_pkg::tl_meta_t       pkt_cpl_meta_i,
  input logic                   pkt_cpl_meta_valid_i,
  output logic                  pkt_cpl_meta_ready_o,

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

localparam int GRANT_NONE = 3'b000;
localparam int GRANT_CPL = 3'b001;
localparam int GRANT_NP  = 3'b010;
localparam int GRANT_P   = 3'b100;
localparam int posted_count_max = 4'd15;
localparam int np_count_max     = 4'd8;


typedef enum logic [1:0] {
  IDLE = 2'd0,
  HDR  = 2'd1,
  DATA = 2'd2
} fsm_e;


fsm_e fsm_state, fsm_next;

logic [3:0] posted_count;
logic [3:0] np_count;

logic [2:0] grant_state;

tl_pkg::tl_meta_t current_pkt_meta;


// TODO: round-robin or priority
logic posted_eligible = ph_credit_ok_i && pkt_posted_valid_i && (!pkt_posted_i.data[126] || pd_credit_ok_i);
logic np_eligible     = nph_credit_ok_i && pkt_np_valid_i && (!pkt_np_i.data[126] || npd_credit_ok_i);
logic cpl_eligible    = cplh_credit_ok_i && pkt_cpl_valid_i && (!pkt_cpl_i.data[126] || cpld_credit_ok_i);

always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    fsm_state <= IDLE;
  end
  else begin
    fsm_state <= fsm_next;
  end
end

always_comb begin
  fsm_next = fsm_state;
  case(fsm)
    IDLE: begin
      if(tl_tx_ready_i) begin
        if(cpl_eligible || np_eligible || posted_eligible) begin
          fsm_next = HDR;
        end
    end
    end
    HDR: begin
      if(tl_tx_ready_i) begin
        if(current_pkt_meta.has_data) begin
          fsm_next = DATA;
        end
        else begin
          fsm_next = IDLE;
        end
      end
    end
    DATA: begin
      if(tl_tx_ready_i && tl_tx_o.eop) begin
        fsm_next = IDLE;
      end
    end
    default: fsm_next = IDLE;
  endcase
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    current_pkt_meta <= '0;
  end
  else begin
    if(fsm_state == HDR && tl_tx_ready_i) begin
      case (grant_state)
        GRANT_CPL: begin
          if(pkt_cpl_meta_valid_i) begin
            current_pkt_meta <= pkt_cpl_meta_i;
            pkt_cpl_meta_ready_o <= 1'b1;
          end
        end
        GRANT_NP : begin
          if(pkt_np_meta_valid_i) begin
            current_pkt_meta <= pkt_np_meta_i;
            pkt_np_meta_ready_o <= 1'b1;
          end
        end
        GRANT_P  : begin
          if(pkt_posted_meta_valid_i) begin
            current_pkt_meta <= pkt_posted_meta_i;
            pkt_posted_meta_ready_o <= 1'b1;
          end
        end
        default: current_pkt_meta <= '0;
      endcase
    end
  end
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    tl_tx_o <= '0;
  end
  else begin
    // Load packet when leaving IDLE and entering HDR
    if(fsm_state == HDR && tl_tx_ready_i) begin
      case (grant_state)
        GRANT_CPL: tl_tx_o <= pkt_cpl_i;
        GRANT_NP : tl_tx_o <= pkt_np_i;
        GRANT_P  : tl_tx_o <= pkt_posted_i;
        default  : tl_tx_o <= '0;
      endcase
    end
    else if(fsm_state == DATA && tl_tx_ready_i) begin
      case (grant_state)
        GRANT_CPL: tl_tx_o <= pkt_cpl_i;
        GRANT_NP : tl_tx_o <= pkt_np_i;
        GRANT_P  : tl_tx_o <= pkt_posted_i;
        default  : tl_tx_o <= '0;
      endcase
    end
    else if(fsm_state == IDLE) begin
      tl_tx_o <= '0;
    end
  end
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    pkt_posted_ready_o <= 1'b0;
    pkt_np_ready_o     <= 1'b0;
    pkt_cpl_ready_o    <= 1'b0;
  end
  else begin
    case(fsm_state)
      IDLE: begin
        pkt_posted_ready_o <= 1'b0;
        pkt_np_ready_o     <= 1'b0;
        pkt_cpl_ready_o    <= 1'b0;
      end
      HDR, DATA: begin
        pkt_posted_ready_o <= (grant_state == GRANT_P) && tl_tx_ready_i;
        pkt_np_ready_o     <= (grant_state == GRANT_NP) && tl_tx_ready_i;
        pkt_cpl_ready_o    <= (grant_state == GRANT_CPL) && tl_tx_ready_i;
      end
      default: begin
        pkt_posted_ready_o <= 1'b0;
        pkt_np_ready_o     <= 1'b0;
        pkt_cpl_ready_o    <= 1'b0;
      end
    endcase
  end
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    tl_tx_valid_o <= 1'b0;
  end
  else begin
    case(fsm_state)
      IDLE: begin
          tl_tx_valid_o <= 1'b0;
        end
      HDR, DATA: begin
        if(tl_tx_ready_i) begin
          if(tl_tx_o.eop) begin
            tl_tx_valid_o <= 1'b0;
          end
          else begin
            tl_tx_valid_o <= 1'b1;
          end
        end
      end
      default: tl_tx_valid_o <= 1'b0;
    endcase
  end
end

 

// Grant logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    grant_state <= GRANT_NONE;
  end
  else if(fsm_state == IDLE && tl_tx_ready_i) begin
    if(np_count == np_count_max && np_eligible) begin
      grant_state <= GRANT_NP;
      np_count <= 4'd0;
    end
    else if(posted_count == posted_count_max && posted_eligible) begin
      grant_state <= GRANT_P;
      posted_count <= 4'd0;
    end
    else if(cpl_eligible) begin
      grant_state <= GRANT_CPL;
      if(posted_count < posted_count_max) begin
        posted_count <= posted_count + 4'd1;
      end
      if(np_count < np_count_max) begin
        np_count <= np_count + 4'd1;
      end
    end
    else if(np_eligible) begin
      grant_state <= GRANT_NP;
      if(posted_count < posted_count_max) begin
        posted_count <= posted_count + 4'd1;
      end
      np_count <= 4'd0;
    end
    else if(posted_eligible) begin
      grant_state <= GRANT_P;
      posted_count <= 4'd0;
    end
  end
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    ph_consume_v_o   <= 1'b0;
    ph_consume_dw_o  <= '0;
    pd_consume_v_o   <= 1'b0;
    pd_consume_dw_o  <= '0;
    nph_consume_v_o  <= 1'b0;
    nph_consume_dw_o <= '0;
    npd_consume_v_o  <= 1'b0;
    npd_consume_dw_o <= '0';
    cplh_consume_v_o <= 1'b0;
    cplh_consume_dw_o<= '0';
    cpld_consume_v_o <= 1'b0;
    cpld_consume_dw_o<= '0';
  end
  else begin
    // Default to no consumption
    ph_consume_v_o   <= 1'b0;
    ph_consume_dw_o  <= '0;
    pd_consume_v_o   <= 1'b0;
    pd_consume_dw_o  <= '0;
    nph_consume_v_o  <= 1'b0;
    nph_consume_dw_o <= '0;
    npd_consume_v_o  <= 1'b0;
    npd_consume_dw_o <= '0';
    cplh_consume_v_o <= 1'b0;
    cplh_consume_dw_o<= '0';
    cpld_consume_v_o <= 1'b0;
    cpld_consume_dw_o<= '0';

    if(fsm_state == HDR && tl_tx_ready_i) begin
      case(grant_state)
        GRANT_P: begin
          ph_consume_v_o  <= 1'b1;
          ph_consume_dw_o <= 1'b1;
          if(current_pkt_meta.has_data) begin
            pd_consume_v_o  <= 1'b1;
            pd_consume_dw_o <= (current_pkt_meta.data_dw + 3) >> 2; // ceil divide by 4
          end
          else begin
            pd_consume_v_o  <= 1'b0;
            pd_consume_dw_o <= '0;
          end
        end
        GRANT_NP: begin
          nph_consume_v_o  <= 1'b1;
          nph_consume_dw_o <= 1'b1;
          if(current_pkt_meta.has_data) begin
            npd_consume_v_o  <= 1'b1;
            npd_consume_dw_o <= (current_pkt_meta.data_dw + 3) >> 2; // ceil divide by 4

          end
          else begin
            npd_consume_v_o  <= 1'b0;
            npd_consume_dw_o <= '0;
          end
        end
        GRANT_CPL: begin
          cplh_consume_v_o <= 1'b1;
          cplh_consume_dw_o<= 1'b1;
          if(current_pkt_meta.has_data) begin
            cpld_consume_v_o <= 1'b1;
            cpld_consume_dw_o<= (current_pkt_meta.data_dw + 3) >> 2; // ceil divide by 4
          end
          else begin
            cpld_consume_v_o <= 1'b0;
            cpld_consume_dw_o<= '0;
          end
        end
      endcase
    end
  end
end

endmodule
