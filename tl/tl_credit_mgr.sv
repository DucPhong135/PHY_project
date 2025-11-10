module tl_credit_mgr #(
  parameter int PH_WIDTH   = 8,
  parameter int PD_WIDTH   = 12,
  parameter int NPH_WIDTH  = 8,
  parameter int NPD_WIDTH  = 12,
  parameter int CPLH_WIDTH = 8,
  parameter int CPLD_WIDTH = 12,
  parameter int MAX_DATA_THRESHOLD = 64 // 1 credit is 4DWs = 64 bytes
  parameter int MAX_HDR_THRESHOLD  = 1 // in headers
)(
  input  logic             clk,
  input  logic             rst_n,

  // ---------------- Increment side (Flow-Control DLLP parser) --------------
  input  tl_pkg::tl_credit_t fc_update_i,
  input  logic               fc_valid_i,

  // ---------------- Decrement pulses from TX engines -----------------------
  input  logic               ph_consume_v_i,
  input  logic [PH_WIDTH-1:0]   ph_consume_dw_i,

  input  logic               pd_consume_v_i,
  input  logic [PD_WIDTH-1:0]   pd_consume_dw_i,

  input  logic               nph_consume_v_i,
  input  logic [NPH_WIDTH-1:0]  nph_consume_dw_i,

  input  logic               npd_consume_v_i,
  input  logic [NPD_WIDTH-1:0]  npd_consume_dw_i,

  input  logic               cplh_consume_v_i,
  input  logic [CPLH_WIDTH-1:0] cplh_consume_dw_i,

  input  logic               cpld_consume_v_i,
  input  logic [CPLD_WIDTH-1:0] cpld_consume_dw_i,

  // ---------------- Availability flags to all TX engines -------------------
  output logic               ph_credit_ok_o,
  output logic               pd_credit_ok_o,
  output logic               nph_credit_ok_o,
  output logic               npd_credit_ok_o,
  output logic               cplh_credit_ok_o,
  output logic               cpld_credit_ok_o
);

  logic [PH_WIDTH-1:0]    ph_avail;
  logic [PD_WIDTH-1:0]    pd_avail;
  logic [NPH_WIDTH-1:0]   nph_avail;
  logic [NPD_WIDTH-1:0]   npd_avail;
  logic [CPLH_WIDTH-1:0]  cplh_avail;
  logic [CPLD_WIDTH-1:0]  cpld_avail;


always_ff @(posedge clk or negedge rst_N) begin
    if(!rst_n) begin
        ph_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(ph_avail + fc_update_i.ph_credits > {PH_WIDTH{1'b1}}) begin
                ph_avail <= {PH_WIDTH{1'b1}}; // saturate
            end
            else
            ph_avail <= ph_avail + fc_update_i.ph_credits;
        end
        if(ph_consume_v_i && ph_credit_ok_o) begin
            ph_avail <= ph_avail - ph_consume_dw_i;
        end
    end
end

assign ph_credit_ok_o = (ph_avail > MAX_HDR_THRESHOLD) ? 1'b1 : 1'b0;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        pd_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(pd_avail + fc_update_i.pd_credits > {PD_WIDTH{1'b1}}) begin
                pd_avail <= {PD_WIDTH{1'b1}}; // saturate
            end
            else
                pd_avail <= pd_avail + fc_update_i.pd_credits;
        end
        if(pd_consume_v_i && pd_credit_ok_o) begin
            pd_avail <= pd_avail - pd_consume_dw_i;
        end
    end
end

assign pd_credit_ok_o = (pd_avail > MAX_DATA_THRESHOLD) ? 1'b1 : 1'b0;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        nph_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(nph_avail + fc_update_i.nph_credits > {NPH_WIDTH{1'b1}}) begin
                nph_avail <= {NPH_WIDTH{1'b1}}; // saturate
            end
            else
            nph_avail <= nph_avail + fc_update_i.nph_credits;
        end
        if(nph_consume_v_i && nph_credit_ok_o) begin
            nph_avail <= nph_avail - nph_consume_dw_i;
        end
    end
end

assign nph_credit_ok_o = (nph_avail > MAX_HDR_THRESHOLD) ? 1'b1 : 1'b0;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        npd_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(npd_avail + fc_update_i.npd_credits > {NPD_WIDTH{1'b1}}) begin
                npd_avail <= {NPD_WIDTH{1'b1}}; // saturate
            end
            else
            npd_avail <= npd_avail + fc_update_i.npd_credits;
        end
        if(npd_consume_v_i && npd_credit_ok_o) begin
            npd_avail <= npd_avail - npd_consume_dw_i;
        end
    end
end

assign npd_credit_ok_o = (npd_avail > MAX_DATA_THRESHOLD) ? 1'b1 : 1'b0;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cplh_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(cplh_avail + fc_update_i.cplh_credits > {CPLH_WIDTH{1'b1}}) begin
                cplh_avail <= {CPLH_WIDTH{1'b1}}; // saturate
            end
            else
            cplh_avail <= cplh_avail + fc_update_i.cplh_credits;
        end
        if(cplh_consume_v_i && cplh_credit_ok_o) begin
            cplh_avail <= cplh_avail - cplh_consume_dw_i;
        end
    end
end

assign cplh_credit_ok_o = (cplh_avail > MAX_HDR_THRESHOLD) ? 1'b1 : 1'b0;

always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        cpld_avail <= '0;
    end
    else begin
        if(fc_valid_i) begin
            if(cpld_avail + fc_update_i.cpld_credits > {CPLD_WIDTH{1'b1}}) begin
                cpld_avail <= {CPLD_WIDTH{1'b1}}; // saturate
            end
            else
            cpld_avail <= cpld_avail + fc_update_i.cpld_credits;
        end
        if(cpld_consume_v_i && cpld_credit_ok_o) begin
            cpld_avail <= cpld_avail - cpld_consume_dw_i;
        end
    end
end

assign cpld_credit_ok_o = (cpld_avail > MAX_DATA_THRESHOLD) ? 1'b1 : 1'b0;

endmodule