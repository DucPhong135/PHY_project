module tl_cpl_gen #(
  parameter int TAG_W = 8,
  parameter int MAX_CPLD_PAYLOAD = 256, // in DWs
  parameter int CPLH_WIDTH = 8,
  parameter int CPLD_WIDTH = 12
)(
  input  logic                   clk,
  input  logic                   rst_n,

  input[15:0]                   requester_id_i, // Requester ID for completions

  // Command input from RX parser (triggered by MRd/ConfigRd)
  input  tl_pkg::cpl_gen_cmd_t   cpl_cmd_i,
  input  logic                   cpl_cmd_valid_i,
  output logic                   cpl_cmd_ready_o,

    // Credit status from Credit Manager
  input  logic                   credit_hdr_ok_i,
  input logic                   credit_data_ok_i,

  output logic                   cplh_consume_v_i,
  output logic [CPLH_WIDTH-1:0]  cplh_consume_dw_i,

  output logic                   cpld_consume_v_i,
  output logic [CPLD_WIDTH-1:0]  cpld_consume_dw_i,

  // Generated Completion Header
  output logic [127:0]           cpl_hdr_o,
  output logic                   cpl_hdr_valid_o,
  input  logic                   cpl_hdr_ready_i,

  // Completion attributes
  output logic                   cpl_has_data_o,   // 1 = CplD, 0 = Cpl
  output logic [255:0]           cpl_data_o,       // completion payload
  output logic                   cpl_data_valid_o,
  input  logic                   cpl_data_ready_i
);


typedef enum logic[2:0] {
  FSM_IDLE,
  FSM_GEN_HDR,
  FSM_SEND_HDR,
  FSM_WAIT_CRED,
  FSM_SEND_DATA
}fsm_state;

fsm_state state, next_state;

tl_pkg::tl_gen_cmd_t cpl_cmd_reg;


  // -----------------------------------------------------------------
  // FSM - Sequential
  // -----------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= FSM_IDLE;
    end else begin
      state <= next_state;
    end
  end

  // -----------------------------------------------------------------
  // FSM - Combinational
  // -----------------------------------------------------------------
  always_comb begin
    // Default assignments
    next_state         = state;

    cpl_cmd_ready_o    = 1'b0;

    cpl_hdr_o          = '0;
    cpl_hdr_valid_o    = 1'b0;

    cpl_has_data_o     = 1'b0;
    cpl_data_o         = '0;
    cpl_data_valid_o   = 1'b0;

    case (state)
      FSM_IDLE: begin
        if (cpl_cmd_valid_i) begin
          cpl_cmd_ready_o = 1'b1;
          next_state = FSM_DECODE;
        end
      end

      FSM_DECODE: begin
        // Decode the command and decide next steps
        if (cpl_cmd_valid_i && cpl_cmd_ready_o) begin
          case (cpl_cmd_i.opcode)
            tl_pkg::OP_CPLD, tl_pkg::OP_CPL: begin
              next_state = FSM_GEN_HDR;
            end
            default: begin
              next_state = FSM_UNSUPPORTED;
            end
          endcase
        end else begin
          next_state = FSM_IDLE; // No valid command, go back to idle
        end
      end
    endcase
  end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cpl_cmd_ready_o <= 1'b0;
  end else begin
    cpl_cmd_ready_o <= (state == FSM_IDLE);
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cpl_cmd_reg <= '0;
  end else begin
    if (cpl_cmd_valid_i && cpl_cmd_ready_o) begin
      cpl_cmd_reg <= cpl_cmd_i;
    end
  end
end

// Header Generation Logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cpl_hdr_o <= '0;
  end else begin
    if(fsm_state == FSM_GEN_HDR) begin
      if(cpl_cmd_reg.cpl_status == 3'd0) begin
        if(cpl_cmd_reg.has_data)
          cpl_hdr_o[127:120] <= 8'h4A; // CPLD
        else
          cpl_hdr_o[127:120] <= 8'h0A; // CPL
          cpl_hdr_o[119:112] <= 8'h00; // Traffic Class 0, No Attributes
          cpl_hdr_o[111] <= 1'b1; // TD
          cpl_hdr_o[110] <= 1'b0; // EP
          cpl_hdr_o[109:106] <= 4'b0000; //Attr and AT bits
        if(cpl_cmd_reg.has_data)
          cpl_hdr_o[105:96] <= (cpl_cmd_reg.byte_count+10'd3) >> 2; // Length in DW for CPLD
        else
          cpl_hdr_o[105:96] <= 10'd1; // Length 0 for CPL
          cpl_hdr_o[95:80] <= requester_id_i; // Completer ID from command
          cpl_hdr_o[79:77] <= cpl_cmd_reg.cpl_status; // Completion Status
          cpl_hdr_o[76] <= 1'b0; // BCM
          if(cpl_cmd_reg.has_data)
            cpl_hdr_o[75:64] <= cpl_cmd_reg.byte_count; // Byte Count
          else
            cpl_hdr_o[75:64] <= 12'h4; // Byte Count 0 for CPL
          cpl_hdr_o[63:48] <= cpl_cmd_reg.requester_id; // Requester ID from command
          cpl_hdr_o[47:40] <= cpl_cmd_reg.tag; // Tag from command
        if(cpl_cmd_reg.has_data)
          cpl_hdr_o[39:32] <= {1'b0, cpl_cmd_reg.lower_addr}; // Lower Address
        else
          cpl_hdr_o[39:32] <= 8'h00; // Lower Address 0 for CPL
          cpl_hdr_o[31:0] <= 32'h0000_0000; // Reserved
      end
    else if(cpl_cmd_reg.cpl_status == 3'd1) begin
      // Unsupported Completion Status - UR
          cpl_hdr_o[127:120] <= 8'h0A; // CPL
          cpl_hdr_o[119:112] <= 8'h00; // Traffic Class 0, No Attributes
          cpl_hdr_o[111] <= 1'b1; // TD
          cpl_hdr_o[110] <= 1'b0; // EP
          cpl_hdr_o[109:106] <= 4'b0000; //Attr and AT bits
          cpl_hdr_o[105:96] <= 10'd0; // Length 0 for CPL
          cpl_hdr_o[95:80] <= requester_id_i; // Completer ID from command
          cpl_hdr_o[79:77] <= cpl_cmd_reg.cpl_status; // Completion Status
          cpl_hdr_o[76] <= 1'b0; // BCM
          cpl_hdr_o[63:48] <= cpl_cmd_reg.requester_id; // Requester ID from command
          cpl_hdr_o[47:40] <= cpl_cmd_reg.tag; // Tag from command
          cpl_hdr_o[39:32] <= 8'h00; // Lower Address 0 for CPL
          cpl_hdr_o[31:0] <= 32'h0000_0000; // Reserved
      end
    end
  end
end

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cpl_hdr_valid_o <= 1'b0;
    end else begin
        if(cpl_hdr_valid_o == 1'b1) 
            cpl_hdr_valid_o <= 1'b0; // de-assert after one cycle
        else if (fsm_state == FSM_SEND_HDR) begin
                if (cpl_hdr_ready_i && credit_ok_i) 
                    cpl_hdr_valid_o <= 1'b1;
                else 
                    cpl_hdr_valid_o <= 1'b0;
            end else begin
                cpl_hdr_valid_o <= 1'b0;
            end
    end
end

assign cpl_has_data_o = (state == FSM_SEND_DATA) && cpl_cmd_reg.has_data;
assign cpl_data_o = if(state == FSM_SEND_DATA && cpl_cmd_reg.has_data) cpl_cmd_reg.data; else '0;
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cpl_data_valid_o <= 1'b0;
    end else begin
        if(cpl_data_valid_o == 1'b1 && cpl_data_ready_i) 
            cpl_data_valid_o <= 1'b0; // de-assert after one cycle
        else if (fsm_state == FSM_SEND_DATA) begin
                if (cpl_cmd_reg.has_data && credit_ok_i) 
                    cpl_data_valid_o <= 1'b1;
                else 
                    cpl_data_valid_o <= 1'b0;
            end else begin
                cpl_data_valid_o <= 1'b0;
            end
    end
end


endmodule
