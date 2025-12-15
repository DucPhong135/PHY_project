module tl_rx_parser 
import tl_pkg::*;
#(
  parameter int TAG_W = 8
)
(
  input  logic                   clk,
  input  logic                   rst_n,

  // Stream from DLL
  input  tl_stream_t             tl_rx_i,
  input  logic                   tl_rx_valid_i,
  output logic                   tl_rx_ready_o,

  // Memory Write to user
  output memrq_t                 memwr_rq_o,
  output logic                   memwr_rq_valid_o,
  input  logic                   memwr_rq_ready_i,


  output logic [127:0]  memwr_data_o,
  output logic                   memwr_data_valid_o,
  input  logic                   memwr_data_ready_i,
  // Forward completion info to completion engine
  output cpl_rx_t        cpl_o,
  output logic                   cpl_valid_o,
  input  logic                   cpl_ready_i,

  // -> to completion generator (for MRd received)
  output cpl_gen_cmd_t cpl_cmd_o,
  output logic                 cpl_cmd_valid_o,
  input  logic                 cpl_cmd_ready_i
);

typedef enum int {
  TL_MRD,
  TL_MWR,
  TL_CPL,
  TL_CPLD,
  TL_OTHERS
} pkt_type_e;

pkt_type_e pkt_type;


typedef enum logic [2:0] {
    ST_IDLE,  
    ST_DECODE_HDR,    
    ST_ROUTE_PKT,     
    ST_DATA_BEAT,     
    ST_DROP_PKT       
} state_e;

  // ========== Registers ==========
  state_e fsm_state, fsm_next;
  
  logic [127:0] hdr_reg;                
  logic is_4dw_hdr;            
  logic [9:0] length_dw;       
  logic [9:0] dw_count;
  logic [9:0] remaining_dw;
  logic is_last_data_beat;
  
  // Buffer for 3DW header's first DW (for alignment)
  logic [31:0] buffered_dw;        // Holds sliding DW for 3DW alignment


  // Byte enable signals
  logic [3:0] first_be;
  logic [3:0] last_be;

  logic last_data_beat;
  assign last_data_beat = (remaining_dw <= 10'd4) ? 1'b1 : 1'b0;

  // Extract BE from header
assign first_be = hdr_reg[59:56];
assign last_be  = hdr_reg[63:60];

assign remaining_dw = length_dw - dw_count;

  // ========== FSM State Register ==========
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      fsm_state <= ST_IDLE;
    else
      fsm_state <= fsm_next;
  end

   // ========== FSM Next State Logic ==========
  always_comb begin
    fsm_next = fsm_state;
    
    case (fsm_state)
      ST_IDLE: begin
        if (tl_rx_valid_i && tl_rx_ready_o) begin
          fsm_next = ST_ROUTE_PKT;
        end
      end
      
      ST_ROUTE_PKT: begin
        case (pkt_type)
          TL_MRD: begin
            if (cpl_cmd_ready_i && cpl_cmd_valid_o) begin
              fsm_next = ST_IDLE; // Done, return to idle
            end
          end
          
          TL_MWR: begin
            if (memwr_rq_ready_i && memwr_rq_valid_o) begin
              if (!is_4dw_hdr) begin
                // 3DW: Buffer first DW, always go to DATA_BEAT to send aligned data
                // Even if only 1 DW total, send it in DATA_BEAT for consistency
                fsm_next = ST_DATA_BEAT;
              end else begin
                // 4DW: No data in header beat
                if (length_dw == 10'd0) begin
                  fsm_next = ST_IDLE;
                end else begin
                  // Data starts in next beat
                  fsm_next = ST_DATA_BEAT;
                end
              end
            end
          end
    
          
          TL_CPL: begin
            if (cpl_ready_i && cpl_valid_o) begin
              fsm_next = ST_IDLE;
            end
          end
          
          TL_CPLD: begin
            if (cpl_ready_i && cpl_valid_o) begin
              if (length_dw <= 10'd1) begin
                // Single DW or no data → Done
                fsm_next = ST_IDLE;
              end else begin
                // Multi-DW completion → Stream remaining DWs
                fsm_next = ST_DATA_BEAT;
              end
            end
          end
          
          default: begin
            fsm_next = ST_DROP_PKT;
          end
        endcase
      end
      
      ST_DATA_BEAT: begin
        if(pkt_type == TL_MWR) begin
          if(memwr_data_valid_o && memwr_data_ready_i) begin
            if (last_data_beat) begin
              fsm_next = ST_IDLE;
            end
          end
        end
        else if (pkt_type == TL_CPLD) begin
          if (cpl_valid_o && cpl_ready_i) begin
            if (last_data_beat) begin
              fsm_next = ST_IDLE;
            end
          end
        end
      end
      
      ST_DROP_PKT: begin
        if (tl_rx_valid_i && tl_rx_ready_o && tl_rx_i.eop) begin
          fsm_next = ST_IDLE;
        end
      end
      
      default: fsm_next = ST_IDLE;
    endcase
  end

  // ========== Latch Header & Decode ==========
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hdr_reg          <= '0;
    end else if (fsm_state == ST_IDLE && tl_rx_valid_i && tl_rx_i.sop) begin
      // Latch incoming header
      hdr_reg <= tl_rx_i.data;
    end
  end


  always_comb begin
      // Decode packet type from Fmt[2:0] and Type[4:0]
      case (hdr_reg[7:5]) // Fmt
        3'b000: begin // 3DW, no data
          is_4dw_hdr = 1'b0;
          case (hdr_reg[4:0])
            5'b00000: pkt_type = TL_MRD;
            5'b01010: pkt_type = TL_CPL;
            default:  pkt_type = TL_OTHERS;
          endcase
        end
        
        3'b001: begin // 4DW, no data
          is_4dw_hdr = 1'b1;
          pkt_type   = TL_MRD;
        end
        
        3'b010: begin // 3DW, with data
          is_4dw_hdr = 1'b0;
          case (hdr_reg[4:0])
            5'b00000: pkt_type = TL_MWR;
            5'b01010: pkt_type = TL_CPLD;
            default:  pkt_type = TL_OTHERS;
          endcase
        end
        
        3'b011: begin // 4DW, with data
          is_4dw_hdr = 1'b1;
          pkt_type   = TL_MWR;
        end
        
        default: pkt_type = TL_OTHERS;
      endcase

        // Length in DWs for MRd/MWr
        length_dw    = {hdr_reg[17:16], hdr_reg[31:24]};  // Corrected bits [9:0]  
  end



  // ========== Ready Signal Logic ==========
  always_comb begin
    tl_rx_ready_o = 1'b0;
    case (fsm_state)
      ST_IDLE: begin
        tl_rx_ready_o = 1'b1; // Ready to accept new packet
      end
      ST_ROUTE_PKT: begin
        // Ready if downstream can accept
        tl_rx_ready_o = 1'b0;
      end
      
      ST_DATA_BEAT: begin
        // Ready if downstream can accept
        case (pkt_type)
          TL_MWR:  tl_rx_ready_o = memwr_data_ready_i;
          TL_CPLD: tl_rx_ready_o = cpl_ready_i;
          default: tl_rx_ready_o = 1'b1;
        endcase
      end
      
      ST_DROP_PKT: begin
        tl_rx_ready_o = 1'b1; // Consume and drop
      end
      
      default: tl_rx_ready_o = 1'b0;
    endcase
  end



always_comb begin
  memwr_rq_o = '0;
  if(fsm_state == ST_ROUTE_PKT && pkt_type == TL_MWR) begin
    memwr_rq_o.addr = (is_4dw_hdr) ? {hdr_reg[71:64], hdr_reg[79:72], hdr_reg[87:80], hdr_reg[95:88], hdr_reg[103:96], hdr_reg[111:104], hdr_reg[119:112], hdr_reg[127:120]} : {32'b0, hdr_reg[71:64], hdr_reg[79:72], hdr_reg[87:80], hdr_reg[95:88]};
    memwr_rq_o.length = length_dw;
    memwr_rq_o.first_be = first_be;
    memwr_rq_o.last_be  = last_be;
  end
end

always_comb begin
  memwr_rq_valid_o = 1'b0;
  if(fsm_state == ST_ROUTE_PKT && pkt_type == TL_MWR) begin
    if(memwr_rq_ready_i) begin
      memwr_rq_valid_o = 1'b1;
    end
  end
end

always_comb begin
  memwr_data_o = 128'd0;
  if(fsm_state == ST_DATA_BEAT && pkt_type == TL_MWR) begin
    if(!is_4dw_hdr) begin
      // 3DW: Use buffered DW + incoming data
      if(remaining_dw >= 10'd4) begin
        // Full 4 DWs available
        memwr_data_o = {tl_rx_i.data[95:64], tl_rx_i.data[63:32], tl_rx_i.data[31:0], buffered_dw};
      end else begin
        // Less than 4 DWs remaining, align accordingly
        case (remaining_dw)
          10'd3: memwr_data_o = {32'd0, tl_rx_i.data[64:32], tl_rx_i.data[31:0], buffered_dw};
          10'd2: memwr_data_o = {64'd0, tl_rx_i.data[31:0], buffered_dw};
          10'd1: memwr_data_o = {96'd0, buffered_dw};
          default: memwr_data_o = 128'd0;
        endcase
      end
    end else begin
      // 4DW: Directly use incoming data
      if(remaining_dw >= 10'd4) begin
        memwr_data_o = tl_rx_i.data;
      end else begin
        // Less than 4 DWs remaining, align accordingly
        case (remaining_dw)
          10'd3: memwr_data_o = {32'd0, tl_rx_i.data[95:0]};
          10'd2: memwr_data_o = {64'd0, tl_rx_i.data[63:0]};
          10'd1: memwr_data_o = {96'd0, tl_rx_i.data[31:0]};
          default: memwr_data_o = 128'd0;
        endcase
      end
    end
  end
end



always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    buffered_dw <= 32'd0;
  end else if (fsm_state == ST_ROUTE_PKT && pkt_type == TL_MWR && !is_4dw_hdr) begin
    // Buffer first DW from header for 3DW MWr
    buffered_dw <= hdr_reg[127:96];
  end else if (fsm_state == ST_DATA_BEAT && pkt_type == TL_MWR && !is_4dw_hdr && memwr_data_ready_i && tl_rx_valid_i) begin
    // Shift in new DW for next beat
    buffered_dw <= tl_rx_i.data[127:96];
  end
  else if (fsm_state == ST_IDLE) begin
    buffered_dw <= 32'd0;
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    dw_count <= 10'd0;
  end 
  else if (fsm_state == ST_ROUTE_PKT && pkt_type == TL_MWR) begin
      dw_count <= 10'd0; // No data in request header
  end
  else if(fsm_state == ST_ROUTE_PKT && pkt_type == TL_CPLD) begin
      dw_count <= 10'd1; // One data DW in header
  end
  else if (fsm_state == ST_DATA_BEAT) begin
      case(pkt_type)
        TL_MWR: begin
          if(memwr_data_ready_i && tl_rx_valid_i) begin
            dw_count <= dw_count + ((remaining_dw > 10'd4) ? 10'd4 : remaining_dw);
          end
        end
        TL_CPLD: begin
          if(cpl_ready_i && cpl_valid_o) begin
            dw_count <= dw_count + ((remaining_dw > 10'd4) ? 10'd4 : remaining_dw);
          end
        end
      endcase
  end else if (fsm_state == ST_IDLE) begin
    dw_count <= 10'd0;
  end
end


always_comb begin
  memwr_data_valid_o = 1'b0;
  if(fsm_state == ST_DATA_BEAT && pkt_type == TL_MWR) begin
    if(!is_4dw_hdr) begin
      if(remaining_dw <= 10'd1) begin
        memwr_data_valid_o = memwr_data_ready_i;
      end else begin
        memwr_data_valid_o = memwr_data_ready_i && tl_rx_valid_i;
      end
    end else begin
      memwr_data_valid_o = memwr_data_ready_i && tl_rx_valid_i;
    end
  end
end

// Function to count enabled bytes in byte enable field
function automatic logic [2:0] popcount4(input logic [3:0] be);
  return be[0] + be[1] + be[2] + be[3];
endfunction

// Calculate correct byte count based on length and byte enables
logic [11:0] mrd_byte_count;
always_comb begin
  if (length_dw == 10'd1) begin
    // Single DW: only first_be matters
    mrd_byte_count = {9'd0, popcount4(first_be)};
  end else begin
    // More than 2 DWs: first + middle (full DWs) + last
    mrd_byte_count = {9'd0, popcount4(first_be)} 
                     + ((length_dw - 10'd2) << 2)  // Middle DWs * 4
                     + {9'd0, popcount4(last_be)};
  end
end

always_comb begin
  cpl_cmd_o = '0;
  cpl_cmd_valid_o = 1'b0;
  if(fsm_state == ST_ROUTE_PKT && (pkt_type == TL_MRD)) begin
    cpl_cmd_o.requester_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_cmd_o.tag          = hdr_reg[55:48];
    cpl_cmd_o.byte_count   = mrd_byte_count;
    cpl_cmd_o.addr    = (is_4dw_hdr) ? {hdr_reg[71:64], hdr_reg[79:72], hdr_reg[87:80], hdr_reg[95:88], hdr_reg[103:96], hdr_reg[111:104], hdr_reg[119:112], hdr_reg[127:120]} : {32'b0, hdr_reg[71:64], hdr_reg[79:72], hdr_reg[87:80], hdr_reg[95:88]};
    cpl_cmd_o.first_be = first_be;
    cpl_cmd_o.last_be  = last_be;    
    if(pkt_type == TL_MRD) begin
      cpl_cmd_o.has_data = 1'b1;
      cpl_cmd_o.cpl_status = tl_pkg::CPL_SUCCESS;
    end
    
    if(cpl_cmd_ready_i) begin
      cpl_cmd_valid_o = 1'b1;
    end
  end
  else if(fsm_state == ST_ROUTE_PKT && pkt_type == TL_OTHERS) begin
    // Unsupported request: Return UR (Unsupported Request) completion
    cpl_cmd_o.requester_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_cmd_o.tag          = hdr_reg[55:48];
    cpl_cmd_o.byte_count   = 12'd0;  // No data for UR
    cpl_cmd_o.addr   = 7'd0;
    cpl_cmd_o.first_be     = first_be;
    cpl_cmd_o.last_be      = last_be;
    cpl_cmd_o.has_data     = 1'b0;
    cpl_cmd_o.cpl_status   = tl_pkg::CPL_UR;  // Unsupported Request
    
    if(cpl_cmd_ready_i) begin
      cpl_cmd_valid_o = 1'b1;
    end
  end
end


always_comb begin
  cpl_o = '0;
  cpl_valid_o = 1'b0;

  if(fsm_state == ST_ROUTE_PKT && (pkt_type == TL_CPL || pkt_type == TL_CPLD)) begin
    cpl_o.sop = 1'b1;
    cpl_o.eop = (pkt_type == TL_CPL) ? 1'b1 : (length_dw == 10'd1) ? 1'b1 : 1'b0;
    cpl_o.completer_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_o.requester_id = {hdr_reg[71:64], hdr_reg[79:72]};
    cpl_o.tag          = hdr_reg[87:80];
    cpl_o.status       = hdr_reg[55:53];
    cpl_o.byte_count   = {hdr_reg[51:48], hdr_reg[63:56]};
    cpl_o.lower_addr   = hdr_reg[94:88];
    cpl_o.has_data     = (pkt_type == TL_CPLD) ? 1'b1 : 1'b0;
    cpl_o.be           = (pkt_type == TL_CPLD) ? {12'hFFF, first_be} : 16'hFFFF; // Full beat if no data
    cpl_o.data         = (pkt_type == TL_CPLD) ? hdr_reg[127:96] : 32'd0;
    if(cpl_ready_i) begin
      cpl_valid_o = 1'b1;
    end
  end else if(fsm_state == ST_DATA_BEAT && pkt_type == TL_CPLD && tl_rx_valid_i) begin
    cpl_o.sop = 1'b0;
    cpl_o.eop = tl_rx_i.eop;
    if(cpl_o.eop) begin
      cpl_o.be = {12'hFFF, last_be};
    end else begin
      cpl_o.be = 16'hFFFF; // All bytes valid for full beats
    end
    cpl_o.data = tl_rx_i.data;
    
    if(cpl_ready_i) begin
      cpl_valid_o = 1'b1;
    end
  end
end



endmodule
