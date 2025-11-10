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

logic [2:0] grant_state;       // Combinational grant decision
logic [2:0] grant_state_reg;   // Registered grant for holding during transmission


tl_pkg::tl_stream_t tl_hdr_o;

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
  case(fsm_state)
    IDLE: begin
      if(tl_tx_ready_i) begin
        if(cpl_eligible || np_eligible || posted_eligible) begin
          fsm_next = HDR;
        end
    end
    end
    HDR: begin
      if(tl_tx_ready_i) begin
        if(tl_hdr_o.data[6] == 1'b1) begin
          fsm_next = DATA;
        end
        else begin
          fsm_next = IDLE;
        end
      end
    end
    DATA: begin
      if(tl_tx_ready_i) begin
        // Detect EOP from the current packet being transmitted
        case (grant_state)
          GRANT_CPL: begin
            if(pkt_cpl_i.eop) begin
              fsm_next = IDLE;  // EOP detected
            end
            else begin
              fsm_next = DATA;  // More data beats to send
            end
          end
          GRANT_NP: begin
            if(pkt_np_i.eop) begin
              fsm_next = IDLE;
            end
            else begin
              fsm_next = DATA;
            end
          end
          GRANT_P: begin
            if(pkt_posted_i.eop) begin
              fsm_next = IDLE;
            end
            else begin
              fsm_next = DATA;
            end
          end
          default: fsm_next = IDLE;
        endcase
      end
    end
    default: fsm_next = IDLE;
  endcase
end




// Latch header when transitioning from IDLE to HDR
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    tl_hdr_o <= '0;
  end
  else begin
    // Capture header on transition from IDLE to HDR (when arbiter makes grant decision)
    if(fsm_state == IDLE && tl_tx_ready_i && (cpl_eligible || np_eligible || posted_eligible)) begin
      case (grant_state)
        GRANT_CPL: tl_hdr_o <= pkt_cpl_i;
        GRANT_NP : tl_hdr_o <= pkt_np_i;
        GRANT_P  : tl_hdr_o <= pkt_posted_i;
        default  : tl_hdr_o <= '0;
      endcase
    end
  end
end

// Output packet data - from latched header in HDR state, or directly from input in DATA state
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    tl_tx_o <= '0;
  end
  else begin
    if(fsm_state == HDR && tl_tx_ready_i) begin
      // Use latched header in HDR state
      tl_tx_o <= tl_hdr_o;
    end
    else if(fsm_state == DATA && tl_tx_ready_i) begin
      // Pass through data beats directly from input queues
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


// Ready signals - combinational, indicates arbiter can accept packets
always_comb begin
  case(fsm_state)
    IDLE: begin
      // In IDLE, ready to accept new packets if downstream is ready
      pkt_posted_ready_o = tl_tx_ready_i && posted_eligible;
      pkt_np_ready_o     = tl_tx_ready_i && np_eligible;
      pkt_cpl_ready_o    = tl_tx_ready_i && cpl_eligible;
    end
    HDR, DATA: begin
      // During transmission, only the granted source gets ready signal
      pkt_posted_ready_o = (grant_state == GRANT_P) && tl_tx_ready_i;
      pkt_np_ready_o     = (grant_state == GRANT_NP) && tl_tx_ready_i;
      pkt_cpl_ready_o    = (grant_state == GRANT_CPL) && tl_tx_ready_i;
    end
    default: begin
      pkt_posted_ready_o = 1'b0;
      pkt_np_ready_o     = 1'b0;
      pkt_cpl_ready_o    = 1'b0;
    end
  endcase
end


// Combinational valid output - asserts when we have valid data to transmit
always_comb begin
  case(fsm_state)
    IDLE: begin
      tl_tx_valid_o = 1'b0;
    end
    HDR: begin
      // Valid when we have a valid packet from the granted source AND downstream is ready
      case(grant_state)
        GRANT_CPL: tl_tx_valid_o = pkt_cpl_valid_i && tl_tx_ready_i;
        GRANT_NP:  tl_tx_valid_o = pkt_np_valid_i && tl_tx_ready_i;
        GRANT_P:   tl_tx_valid_o = pkt_posted_valid_i && tl_tx_ready_i;
        default:   tl_tx_valid_o = 1'b0;
      endcase
    end
    DATA: begin
      // Valid when we have valid data from the granted source AND downstream is ready
      case(grant_state)
        GRANT_CPL: tl_tx_valid_o = pkt_cpl_valid_i && tl_tx_ready_i;
        GRANT_NP:  tl_tx_valid_o = pkt_np_valid_i && tl_tx_ready_i;
        GRANT_P:   tl_tx_valid_o = pkt_posted_valid_i && tl_tx_ready_i;
        default:   tl_tx_valid_o = 1'b0;
      endcase
    end
    default: tl_tx_valid_o = 1'b0;
  endcase
end

 

// Combinational grant decision - determines which queue to grant based on priority and fairness
always_comb begin
  grant_state = GRANT_NONE;
  
  if(fsm_state == IDLE) begin
    // Make arbitration decision in IDLE state
    if(tl_tx_ready_i && (cpl_eligible || np_eligible || posted_eligible)) begin
      // Priority arbitration with fairness counters
      if(np_count == np_count_max && np_eligible) begin
        grant_state = GRANT_NP;
      end
      else if(posted_count == posted_count_max && posted_eligible) begin
        grant_state = GRANT_P;
      end
      else if(cpl_eligible) begin
        grant_state = GRANT_CPL;
      end
      else if(np_eligible) begin
        grant_state = GRANT_NP;
      end
      else if(posted_eligible) begin
        grant_state = GRANT_P;
      end
      else begin
        grant_state = GRANT_NONE;
      end
    end
  end
  else begin
    // During HDR and DATA states, use registered grant
    grant_state = grant_state_reg;
  end
end

// Register the grant decision and update fairness counters
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    grant_state_reg <= GRANT_NONE;
    posted_count <= 4'd0;
    np_count <= 4'd0;
  end
  else begin
    case(fsm_state)
      IDLE: begin
        // Latch grant decision when transitioning to HDR
        if(tl_tx_ready_i && (cpl_eligible || np_eligible || posted_eligible)) begin
          grant_state_reg <= grant_state;
          
          // Update fairness counters based on grant decision
          case(grant_state)
            GRANT_NP: begin
              np_count <= 4'd0;
              if(posted_count < posted_count_max) begin
                posted_count <= posted_count + 4'd1;
              end
            end
            GRANT_P: begin
              posted_count <= 4'd0;
            end
            GRANT_CPL: begin
              if(posted_count < posted_count_max) begin
                posted_count <= posted_count + 4'd1;
              end
              if(np_count < np_count_max) begin
                np_count <= np_count + 4'd1;
              end
            end
          endcase
        end
      end
      
      HDR, DATA: begin
        // Hold grant during transmission
        grant_state_reg <= grant_state_reg;
      end
      
      default: begin
        grant_state_reg <= GRANT_NONE;
      end
    endcase
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
          if(tl_hdr_o.data[6] == 1'b1) begin
            pd_consume_v_o  <= 1'b1;
            pd_consume_dw_o <= {tl_hdr_o.data[17:16], tl_hdr_o.data[31:24]}; // Already in DWs
          end
          else begin
            pd_consume_v_o  <= 1'b0;
            pd_consume_dw_o <= '0;
          end
        end
        GRANT_NP: begin
          nph_consume_v_o  <= 1'b1;
          nph_consume_dw_o <= 1'b1;
          if(tl_hdr_o.data[6] == 1'b1) begin
            npd_consume_v_o  <= 1'b1;
            npd_consume_dw_o <= {tl_hdr_o.data[17:16], tl_hdr_o.data[31:24]}; // Already in DWs
          end
          else begin
            npd_consume_v_o  <= 1'b0;
            npd_consume_dw_o <= '0;
          end
        end
        GRANT_CPL: begin
          cplh_consume_v_o <= 1'b1;
          cplh_consume_dw_o<= 1'b1;
          if(tl_hdr_o.data[6] == 1'b1) begin
            cpld_consume_v_o <= 1'b1;
            cpld_consume_dw_o<= {tl_hdr_o.data[17:16], tl_hdr_o.data[31:24]}; // Already in DWs
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
