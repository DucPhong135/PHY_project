module tl_cpl_gen 
import tl_pkg::*;
#(
  parameter int TAG_W = 8,
  parameter int MAX_CPLD_PAYLOAD = 1024,
  parameter int CPLH_WIDTH = 8,
  parameter int CPLD_WIDTH = 12
)(
  input  logic                   clk,
  input  logic                   rst_n,

  input[15:0]                   requester_id_i, 


  input  tl_pkg::cpl_gen_cmd_t   cpl_cmd_i,
  input  logic                   cpl_cmd_valid_i,
  output logic                   cpl_cmd_ready_o,


  input  logic                   credit_hdr_ok_i,
  input  logic                   credit_data_ok_i,

  output logic [CPLH_WIDTH-1:0]  cplh_credit_consume_o,
  output logic                   cplh_credit_consume_v_o,

  output logic [CPLD_WIDTH-1:0]  cpld_credit_consume_o,
  output logic                   cpld_credit_consume_v_o,

  output memrq_t           memrd_rq_o,
  output logic             memrd_rq_valid_o,     
  input  logic             memrd_rq_ready_i,      


  input  logic [127:0]     memrd_data_i,       
  input  logic             memrd_data_valid_i, 
  output logic             memrd_data_ready_o,  


  output tl_pkg::tl_stream_t     cpl_pkt_o,
  output logic                   cpl_pkt_valid_o,
  input  logic                   cpl_pkt_ready_i
);


typedef enum logic [2:0] {
  FSM_IDLE,
  FSM_MEM_REQ,
  FSM_GEN_HDR,
  FSM_SEND_HDR,
  FSM_WAIT_CRED,
  FSM_SEND_DATA
} fsm_state_t;

fsm_state_t fsm_state, fsm_next;

tl_pkg::cpl_gen_cmd_t cpl_cmd_reg;


logic [9:0] dw_count;
logic [9:0]  dw_sent;        
logic [9:0]  dw_remaining;      
logic [7:0] beat_count; 
logic [7:0] total_beats;
logic [7:0] data_beat_count;


logic [2:0]  dw_this_beat;
logic        is_last_beat;
logic        is_first_data_beat;

// Internal header register
logic [127:0] cpl_hdr_reg;

logic [95:0] mem_data_buf;


  // -----------------------------------------------------------------
  // FSM - Sequential
  // -----------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fsm_state <= FSM_IDLE;
    end else begin
      fsm_state <= fsm_next;
    end
  end

  // -----------------------------------------------------------------
  // FSM - Combinational
  // -----------------------------------------------------------------
  always_comb begin
    fsm_next = fsm_state;

    case (fsm_state)
      FSM_IDLE: begin
        if (cpl_cmd_valid_i && cpl_cmd_ready_o) begin
          fsm_next = FSM_GEN_HDR;
        end
      end

      FSM_GEN_HDR: begin
            fsm_next = FSM_MEM_REQ;
      end

      FSM_MEM_REQ: begin
        if (memrd_rq_valid_o && memrd_rq_ready_i) begin
          fsm_next = FSM_SEND_HDR;
        end
      end

      FSM_SEND_HDR: begin
        if (cpl_pkt_valid_o && cpl_pkt_ready_i) begin
          if (cpl_cmd_reg.has_data && dw_count > 10'd1) begin
            fsm_next = FSM_SEND_DATA;
          end
          else if(!cpl_cmd_reg.has_data || dw_count == 10'd1) begin
            fsm_next = FSM_IDLE; 
          end
        end
      end
      FSM_SEND_DATA: begin
        if (cpl_pkt_valid_o && cpl_pkt_ready_i) begin
          if (is_last_beat) begin
            fsm_next = FSM_IDLE; 
          end
        end
      end
    endcase
  end


always_comb begin
    cpl_cmd_ready_o = (fsm_state == FSM_IDLE) ? 1'b1 : 1'b0;
end



always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    cpl_cmd_reg <= '0;
    total_beats <= 8'd0;
  end else begin
    if(fsm_state == FSM_IDLE && cpl_cmd_valid_i && cpl_cmd_ready_o) begin
      cpl_cmd_reg <= cpl_cmd_i; 
    end
    else if(fsm_state == FSM_GEN_HDR) begin
      if (cpl_cmd_reg.byte_count > 12'd4) begin
        total_beats <= ((dw_count - 10'd1 + 10'd3) >> 2);
      end else begin
        total_beats <= 8'd0;
      end
    end
  end
end

assign memrd_rq_o.addr  = cpl_cmd_reg.addr;
assign memrd_rq_o.length   = dw_count;
assign memrd_rq_o.first_be = cpl_cmd_reg.first_be;
assign memrd_rq_o.last_be  = cpl_cmd_reg.last_be;

assign memrd_rq_valid_o = (fsm_state == FSM_MEM_REQ) && memrd_rq_ready_i;


assign dw_count = (cpl_cmd_reg.byte_count + 12'd3) >> 2;

assign dw_remaining = dw_count - dw_sent;
assign is_last_beat = (dw_sent + {7'd0, dw_this_beat} >= dw_count);

always_comb begin
  if (fsm_state == FSM_SEND_DATA) begin
    if (dw_remaining >= 10'd4)
      dw_this_beat = 3'd4;
    else if (dw_remaining == 10'd3)
      dw_this_beat = 3'd3;
    else if (dw_remaining == 10'd2)
      dw_this_beat = 3'd2;
    else if (dw_remaining == 10'd1)
      dw_this_beat = 3'd1;
    else
      dw_this_beat = 3'd0;
  end else begin
    dw_this_beat = 3'd0;
  end
end




always_comb begin
  memrd_data_ready_o = 1'b0;
  
  case (fsm_state)
    FSM_SEND_HDR:  memrd_data_ready_o = cpl_pkt_ready_i;
    FSM_SEND_DATA: begin
      if (is_last_beat && dw_this_beat <= 3'd3) begin
        memrd_data_ready_o = 1'b0;  
      end else begin
        memrd_data_ready_o = cpl_pkt_ready_i;
      end
    end
    default: memrd_data_ready_o = 1'b0;
  endcase
end


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    mem_data_buf       <= '0;
  end else begin
    if (fsm_state == FSM_SEND_HDR && memrd_data_valid_i) begin
      mem_data_buf       <= memrd_data_i[127:32];
    end else if (fsm_state == FSM_SEND_DATA && memrd_data_valid_i && memrd_data_ready_o) begin
      mem_data_buf       <= memrd_data_i[127:32];
    end
  end
end



always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    beat_count <= 8'd0;
  end else begin
    if (fsm_state == FSM_IDLE) begin
      beat_count <= 8'd0; 
    end
    else if (fsm_state == FSM_SEND_DATA && cpl_pkt_valid_o && cpl_pkt_ready_i) begin
      beat_count <= beat_count + 8'd1;  
    end
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    dw_sent <= 10'd0;
  end else begin
    if (fsm_state == FSM_IDLE) begin
      dw_sent <= 10'd0;
    end else if (fsm_state == FSM_SEND_HDR && cpl_pkt_valid_o && cpl_pkt_ready_i) begin
      if (cpl_cmd_reg.has_data) begin
        dw_sent <= 10'd1;
      end
    end else if (fsm_state == FSM_SEND_DATA && cpl_pkt_valid_o && cpl_pkt_ready_i) begin
      dw_sent <= dw_sent + {7'd0, dw_this_beat};
    end
  end
end



// Header Generation Logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cpl_hdr_reg <= '0;
  end else begin
    if(fsm_state == FSM_GEN_HDR) begin
      if(cpl_cmd_reg.cpl_status == 3'd0) begin

        if(cpl_cmd_reg.has_data) begin
          cpl_hdr_reg[7:0] <= 8'h4A;
        end
        
        // Common header fields
        cpl_hdr_reg[15:8] <= 8'h00; 
        cpl_hdr_reg[23:16] <= {6'b0, dw_count[9:8]};
        cpl_hdr_reg[31:24] <= dw_count[7:0];
        cpl_hdr_reg[39:32] <= requester_id_i[15:8];
        cpl_hdr_reg[47:40] <= requester_id_i[7:0];
        cpl_hdr_reg[55:53] <= cpl_cmd_reg.cpl_status; 
        cpl_hdr_reg[52] <= 1'b0; 
        cpl_hdr_reg[51:48] <= cpl_cmd_reg.byte_count[11:8];
        cpl_hdr_reg[63:56] <= cpl_cmd_reg.byte_count[7:0];
        cpl_hdr_reg[71:64] <= cpl_cmd_reg.requester_id[15:8]; 
        cpl_hdr_reg[79:72] <= cpl_cmd_reg.requester_id[7:0]; 
        cpl_hdr_reg[87:80] <= cpl_cmd_reg.tag; 
        cpl_hdr_reg[94:88] <= cpl_cmd_reg.addr[6:0]; 
        cpl_hdr_reg[95] <= 1'b0; 
        cpl_hdr_reg[127:96] <= 32'h0000_0000;
      end
    else if(cpl_cmd_reg.cpl_status == 3'd1) begin

      cpl_hdr_reg[7:0] <= 8'h0A;
      cpl_hdr_reg[15:8] <= 8'h00;
      cpl_hdr_reg[23:16] <= {6'b0, dw_count[9:8]};
      cpl_hdr_reg[31:24] <= dw_count[7:0]; 
      cpl_hdr_reg[39:32] <= requester_id_i[15:8]; 
      cpl_hdr_reg[47:40] <= requester_id_i[7:0];
      cpl_hdr_reg[55:53] <= cpl_cmd_reg.cpl_status;
      cpl_hdr_reg[52] <= 1'b0;
      cpl_hdr_reg[51:48] <= cpl_cmd_reg.byte_count[11:8];
      cpl_hdr_reg[63:56] <= cpl_cmd_reg.byte_count[7:0];
      cpl_hdr_reg[71:64] <= cpl_cmd_reg.requester_id[15:8];
      cpl_hdr_reg[79:72] <= cpl_cmd_reg.requester_id[7:0]; 
      cpl_hdr_reg[87:80] <= cpl_cmd_reg.tag;
      cpl_hdr_reg[94:88] <= cpl_cmd_reg.addr[6:0];
      cpl_hdr_reg[95] <= 1'b0; 
      cpl_hdr_reg[127:96] <= 32'h0000_0000; 
    end
    end
  end
end



always_comb begin
  cpl_pkt_o = '0;
  
  case(fsm_state)
    FSM_SEND_HDR: begin

      cpl_pkt_o.data[95:0] = cpl_hdr_reg[95:0];
      cpl_pkt_o.sop = 1'b1;
      if(cpl_cmd_reg.has_data) begin
        cpl_pkt_o.data[127:96] = memrd_data_i[31:0];
        cpl_pkt_o.eop = (dw_count == 1); 
        cpl_pkt_o.is_dllp = 1'b0;
      end
      else begin

        cpl_pkt_o.data[127:96] = 32'h0;
        cpl_pkt_o.sop = 1'b1;
        cpl_pkt_o.eop = 1'b1;
        cpl_pkt_o.is_dllp = 1'b0;
      end
    end
    
    FSM_SEND_DATA: begin
      cpl_pkt_o.sop = 1'b0;
      cpl_pkt_o.eop = (beat_count >= total_beats - 1);
      cpl_pkt_o.is_dllp = 1'b0;
      if (is_last_beat) begin
        case (dw_this_beat)
          3'd1: cpl_pkt_o.data = {96'b0, mem_data_buf[31:0]};
          3'd2: cpl_pkt_o.data = {64'b0, mem_data_buf[63:0]};
          3'd3: cpl_pkt_o.data = {32'b0, mem_data_buf[95:0]};
          3'd4: cpl_pkt_o.data = {memrd_data_i[31:0], mem_data_buf[95:0]};
          default: cpl_pkt_o.data = '0;
        endcase
      end else begin
        cpl_pkt_o.data = {memrd_data_i[31:0], mem_data_buf[95:0]};
      end
    end
    
    default: begin
      cpl_pkt_o = '0;
    end
  endcase
end


always_comb begin
  cpl_pkt_valid_o = 1'b0;
  
  case (fsm_state)
    FSM_SEND_HDR: begin
      if (cpl_cmd_reg.has_data) begin
        cpl_pkt_valid_o = memrd_data_valid_i && credit_hdr_ok_i && credit_data_ok_i && cpl_pkt_ready_i;
      end else begin
        cpl_pkt_valid_o = credit_hdr_ok_i && cpl_pkt_ready_i;
      end
    end
    FSM_SEND_DATA: begin
      if (is_last_beat && dw_this_beat <= 3'd3) begin
        cpl_pkt_valid_o = credit_data_ok_i && cpl_pkt_ready_i;
      end else begin
        cpl_pkt_valid_o = memrd_data_valid_i && credit_data_ok_i && cpl_pkt_ready_i;
      end
    end
    default: cpl_pkt_valid_o = 1'b0;
  endcase
end
endmodule
