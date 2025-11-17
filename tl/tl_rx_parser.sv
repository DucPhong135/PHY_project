module tl_rx_parser #(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Stream from DLL
  input  tl_pkg::tl_stream_t     tl_rx_i,
  input  logic                   tl_rx_valid_i,
  output logic                   tl_rx_ready_o,

  // Memory Write to user
  output tl_pkg::tl_data_t       memwr_o,
  output logic                   memwr_valid_o,
  input  logic                   memwr_ready_i,

  // Forward completion info to completion engine
  output tl_pkg::cpl_rx_t        cpl_o,
  output logic                   cpl_valid_o,
  input  logic                   cpl_ready_i,

  // -> to completion generator (for MRd/CfgRd received)
  output tl_pkg::cpl_gen_cmd_t cpl_cmd_o,
  output logic                 cpl_cmd_valid_o,
  input  logic                 cpl_cmd_ready_i,

  // -> to config space block (CSR read/write side-effects)
  output tl_pkg::cfg_req_t     cfg_req_o,      // {is_read, addr, first_be, last_be, data, length_dw, requester_id, tag}
  output logic                 cfg_req_valid_o,
  input  logic                 cfg_req_ready_i,
);

  // TODO: header decode, ECRC, etc.
typedef enum int {
  TL_MRD,
  TL_MWR,
  TL_CPL,
  TL_CPLD,
  TL_CFGRD,
  TL_CFGWR,
  TL_OTHERS
} pkt_type_e;

pkt_type_e pkt_type;


typedef enum logic [2:0] {
    ST_IDLE,
    ST_LATCH_HDR,     // ← NEW: Latch header for stable decode
    ST_DECODE_HDR,    // ← Decode from registered header
    ST_ROUTE_PKT,     // ← Route based on decoded type
    ST_DATA_BEAT,     // ← Stream multi-beat data
    ST_DROP_PKT       // ← Drop unsupported packets
} state_e;

  // ========== Registers ==========
  state_e fsm_state, fsm_next;
  
  logic [127:0] hdr_reg;           // ← LATCHED header (stable)
  pkt_type_e pkt_type_reg;         // ← DECODED type (stable)
  logic is_4dw_hdr_reg;            // ← Header format (stable)
  logic [9:0] length_dw_reg;       // ← Payload length (stable)
  logic [11:0] dw_count;
  logic is_first_data_beat;
  
  // Buffer for 3DW header's first DW (for alignment)
  logic [31:0] buffered_dw;        // Holds sliding DW for 3DW alignment
  logic buffered_dw_valid;         // Indicates buffered_dw contains valid data

  // Temporary decode signals (combinational, used only in ST_DECODE_HDR)
  pkt_type_e pkt_type_decode;
  logic is_4dw_hdr_decode;

  // Byte enable signals
  logic [3:0] first_be;
  logic [3:0] last_be;
  logic [2:0] byte_en_first;
  logic [2:0] byte_en_last;

  // Extract BE from header
assign first_be = hdr_reg[59:56];
assign last_be  = hdr_reg[63:60];

  // ========== FSM State Register ==========
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      fsm_state <= ST_IDLE;
    else
      fsm_state <= fsm_next;
  end

  // ========== Latch Header & Decode ==========
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hdr_reg          <= '0;
      pkt_type_reg     <= TL_OTHERS;
      is_4dw_hdr_reg   <= 1'b0;
      length_dw_reg    <= '0;
      dw_count         <= '0;
      is_first_data_beat <= 1'b0;
      buffered_dw      <= '0;
      buffered_dw_valid <= 1'b0;
    end else if (fsm_state == ST_IDLE && tl_rx_valid_i && tl_rx_i.sop) begin
      // Latch incoming header
      hdr_reg <= tl_rx_i.data;
      
      // Decode packet type from Fmt[2:0] and Type[4:0]
      case (tl_rx_i.data[7:5]) // Fmt
        3'b000: begin // 3DW, no data
          is_4dw_hdr_reg <= 1'b0;
          case (tl_rx_i.data[4:0])
            5'b00000: pkt_type_reg <= TL_MRD;
            5'b00100: pkt_type_reg <= TL_CFGRD;
            5'b01010: pkt_type_reg <= TL_CPL;
            default:  pkt_type_reg <= TL_OTHERS;
          endcase
        end
        
        3'b001: begin // 4DW, no data
          is_4dw_hdr_reg <= 1'b1;
          pkt_type_reg   <= TL_MRD;
        end
        
        3'b010: begin // 3DW, with data
          is_4dw_hdr_reg <= 1'b0;
          case (tl_rx_i.data[4:0])
            5'b00000: pkt_type_reg <= TL_MWR;
            5'b00100: pkt_type_reg <= TL_CFGWR;
            5'b01010: pkt_type_reg <= TL_CPLD;
            default:  pkt_type_reg <= TL_OTHERS;
          endcase
        end
        
        3'b011: begin // 4DW, with data
          is_4dw_hdr_reg <= 1'b1;
          pkt_type_reg   <= TL_MWR;
        end
        
        default: pkt_type_reg <= TL_OTHERS;
      endcase
      
      length_dw_reg    <= {tl_rx_i.data[17:16], tl_rx_i.data[31:24]};  // Corrected bits [9:0]
      dw_count         <= '0;
      is_first_data_beat <= 1'b1;
      buffered_dw      <= '0;
      buffered_dw_valid <= 1'b0;
      
      end else if (fsm_state == ST_ROUTE_PKT) begin
        // For 3DW writes, buffer first DW from header for alignment
        if (pkt_type_reg == TL_MWR && !is_4dw_hdr_reg && memwr_ready_i) begin
          buffered_dw <= hdr_reg[127:96];  // Buffer first DW
          buffered_dw_valid <= 1'b1;
          dw_count <= 12'd1;  // First DW accounted for
        end else if (pkt_type_reg == TL_CPLD) begin
          dw_count <= 12'd1;  // First DW in header for 3DW CplD
        end
        
      end else if (fsm_state == ST_DATA_BEAT && tl_rx_valid_i && tl_rx_ready_o) begin
        dw_count <= dw_count + 12'd4;  // Each beat = 4 DWs
        is_first_data_beat <= 1'b0;
        
        // For 3DW MWr: Update sliding buffer with last DW from current beat
        if (pkt_type_reg == TL_MWR && !is_4dw_hdr_reg && buffered_dw_valid) begin
          if (!tl_rx_i.eop) begin
            // Not last beat: Buffer the 4th DW for next beat
            buffered_dw <= tl_rx_i.data[127:96];
          end else begin
            // Last beat: Clear buffer
            buffered_dw_valid <= 1'b0;
          end
        end
      end
  end


  // ========== FSM Next State Logic ==========
  always_comb begin
    fsm_next = fsm_state;
    
    case (fsm_state)
      ST_IDLE: begin
        if (tl_rx_valid_i && tl_rx_i.sop) begin
          fsm_next = ST_LATCH_HDR;
        end
      end
      
      ST_LATCH_HDR: begin
        // Header latched, move to routing
        fsm_next = ST_ROUTE_PKT;
      end
      
      ST_ROUTE_PKT: begin
        case (pkt_type_reg)
          TL_MRD, TL_CFGRD: begin
            if (cpl_cmd_ready_i) begin
              fsm_next = ST_IDLE; // Done, return to idle
            end
          end
          
          TL_MWR: begin
            if (memwr_ready_i) begin
              if (!is_4dw_hdr_reg) begin
                // 3DW: Buffer first DW, always go to DATA_BEAT to send aligned data
                // Even if only 1 DW total, send it in DATA_BEAT for consistency
                fsm_next = ST_DATA_BEAT;
              end else begin
                // 4DW: No data in header beat
                if (length_dw_reg == 10'd0) begin
                  fsm_next = ST_IDLE;
                end else begin
                  // Data starts in next beat
                  fsm_next = ST_DATA_BEAT;
                end
              end
            end
          end
          
          TL_CFGWR: begin
            if (cfg_req_ready_i) begin
              fsm_next = ST_IDLE;
            end
          end
          
          TL_CPL: begin
            if (cpl_ready_i) begin
              fsm_next = ST_IDLE;
            end
          end
          
          TL_CPLD: begin
            if (cpl_ready_i) begin
              if (length_dw_reg <= 10'd1) begin
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
        if (tl_rx_valid_i && tl_rx_ready_o && tl_rx_i.eop) begin
          fsm_next = ST_IDLE;
        end
      end
      
      ST_DROP_PKT: begin
        if (tl_rx_valid_i && tl_rx_i.eop) begin
          fsm_next = ST_IDLE;
        end
      end
      
      default: fsm_next = ST_IDLE;
    endcase
  end

  // ========== Ready Signal Logic ==========
  always_comb begin
    case (fsm_state)
      ST_IDLE: begin
        tl_rx_ready_o = 1'b1; // Ready to accept new packet
      end
      
      ST_LATCH_HDR, ST_ROUTE_PKT: begin
        tl_rx_ready_o = 1'b0; // Busy processing header
      end
      
      ST_DATA_BEAT: begin
        // Ready if downstream can accept
        case (pkt_type_reg)
          TL_MWR:  tl_rx_ready_o = memwr_ready_i;
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
  case(first_be)
    4'b1111: byte_en_first = 3'b100; // 4-byte aligned
    4'b1110: byte_en_first = 3'b011; // 4-byte aligned + 1 byte
    4'b1100: byte_en_first = 3'b010; // 4-byte aligned + 2 bytes
    4'b1000: byte_en_first = 3'b001; // 4-byte aligned + 3 bytes
    default: byte_en_first = 3'b000; // default to all bytes enabled
  endcase

  case(last_be)
    4'b1111: byte_en_last = 3'b100; // 4-byte aligned
    4'b1110: byte_en_last = 3'b011; // 4-byte aligned + 1 byte
    4'b1100: byte_en_last = 3'b010; // 4-byte aligned + 2 bytes
    4'b1000: byte_en_last = 3'b001; // 4-byte aligned + 3 bytes
    default: byte_en_last = 3'b000; // default to all bytes enabled
  endcase
end


always_comb begin
  memwr_o = '0;
  memwr_valid_o = 1'b0;

  if(fsm_state == ST_DATA_BEAT && pkt_type_reg == TL_MWR && tl_rx_valid_i) begin
    
    if(!is_4dw_hdr_reg && buffered_dw_valid) begin
      // 3DW header case: Sliding window alignment
      // Always combine buffered DW with lower 3 DWs from current beat
      // Data layout: [buffered_dw, tl_rx_i.data[95:64], tl_rx_i.data[63:32], tl_rx_i.data[31:0]]
      memwr_o.data = {tl_rx_i.data[95:0], buffered_dw};
      
      if(is_first_data_beat) begin
        // First beat: Send address and mark SOP
        memwr_o.addr = {32'h0, hdr_reg[95:64]};  // 32-bit address from header
        memwr_o.sop = 1'b1;
      end else begin
        // Subsequent beats: No address, no SOP
        memwr_o.addr = '0;
        memwr_o.sop = 1'b0;
      end
      
      // EOP handling:
      // We need to check if the LAST DW of the TLP is in this output beat
      // Since we're consuming 3 DWs from current beat (leaving 4th for next),
      // EOP happens when tl_rx_i.eop AND we've sent all but the last buffered DW
      // OR when length fits exactly in current output
      
      // Calculate how many DWs we've sent AFTER this beat
      // Current output sends: buffered + 3 DWs from payload
      // Total DWs output so far = dw_count + 3 (we consume 3 from current beat)
      
      if(tl_rx_i.eop) begin
        // Input is ending - check if we have exactly the right amount
        // dw_count already includes buffered DW (incremented in ST_ROUTE_PKT)
        // After this beat: dw_count will be incremented by 4 (but we only use 3 here)
        // So EOP if: dw_count + 3 >= length_dw_reg
        memwr_o.eop = ((dw_count + 12'd3) >= {2'b0, length_dw_reg});
      end else begin
        memwr_o.eop = 1'b0;
      end
      
      // Byte enables:
      if(is_first_data_beat) begin
        if(memwr_o.eop) begin
          // First and last beat: Calculate BE based on total length
          if(length_dw_reg == 10'd1) begin
            // Only 1 DW (buffered) - shouldn't happen (would need payload)
            memwr_o.be = {12'h0, first_be};
          end else if(length_dw_reg == 10'd2) begin
            // 2 DWs: buffered + DW1
            memwr_o.be = {8'h0, last_be, first_be};
          end else if(length_dw_reg == 10'd3) begin
            // 3 DWs: buffered + DW1-2
            memwr_o.be = {4'h0, last_be, 4'hF, first_be};
          end else begin
            // 4 DWs: buffered + DW1-3
            memwr_o.be = {last_be, 4'hF, 4'hF, first_be};
          end
        end else begin
          // First beat but not last: first_be for buffered DW, all enables for rest
          memwr_o.be = {12'hFFF, first_be};
        end
      end else begin
        // Not first beat
        if(memwr_o.eop) begin
          // Last beat: last_be applies to highest valid DW
          // We're outputting buffered + 3 DWs
          // Need to figure out which DW position gets last_be
          logic [11:0] remaining_dws;
          remaining_dws = {2'b0, length_dw_reg} - dw_count;
          
          if(remaining_dws == 12'd1) begin
            memwr_o.be = {12'h0, last_be};  // Only buffered DW
          end else if(remaining_dws == 12'd2) begin
            memwr_o.be = {8'h0, last_be, 4'hF};  // buffered + 1 DW
          end else if(remaining_dws == 12'd3) begin
            memwr_o.be = {4'h0, last_be, 8'hFF};  // buffered + 2 DWs
          end else begin
            memwr_o.be = {last_be, 12'hFFF};  // buffered + 3 DWs
          end
        end else begin
          // Middle beat: All bytes valid
          memwr_o.be = 16'hFFFF;
        end
      end
      
    end else if(is_4dw_hdr_reg) begin
      // 4DW header case: Normal data transfer from payload
      memwr_o.data = tl_rx_i.data;
      
      if(is_first_data_beat) begin
        // First data beat: Send address
        memwr_o.addr = {hdr_reg[95:64], hdr_reg[127:96]};  // 64-bit address
        memwr_o.sop = 1'b1;
      end else begin
        memwr_o.addr = '0;  // Address only in SOP
        memwr_o.sop = 1'b0;
      end
      
      memwr_o.eop = tl_rx_i.eop;
      
      if(tl_rx_i.eop) begin
        memwr_o.be = {12'h0, last_be};  // Last beat uses last_be
      end else if(is_first_data_beat) begin
        memwr_o.be = {12'h0, first_be}; // First data beat uses first_be
      end else begin
        memwr_o.be = 16'hFFFF; // All bytes valid for middle beats
      end
    end
    
    memwr_valid_o = memwr_ready_i;  // Follow project convention
  end
end

always_comb begin
  cpl_cmd_o = '0;
  cpl_cmd_valid_o = 1'b0;
  if(fsm_state == ST_ROUTE_PKT && (pkt_type_reg == TL_MRD || pkt_type_reg == TL_CFGRD)) begin
    cpl_cmd_o.requester_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_cmd_o.tag          = hdr_reg[55:48];
    cpl_cmd_o.byte_count    = length_dw_reg << 2;
    cpl_cmd_o.lower_addr    = is_4dw_hdr_reg ? hdr_reg[126:120] : hdr_reg[94:88];
    cpl_cmd_o.first_be = first_be;
    cpl_cmd_o.last_be  = last_be;    
    if(pkt_type_reg == TL_MRD) begin
      // Memory Read: Return test pattern data (no real memory controller)
      // Option 1: Fixed pattern for testing
      cpl_cmd_o.data = 256'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0_AAAA5555_FFFF0000_A5A5A5A5_5A5A5A5A;
      cpl_cmd_o.has_data = 1'b1;
      cpl_cmd_o.cpl_status = tl_pkg::CPL_SUCCESS;
      
      // Option 2: Return address as data for easy verification (uncomment to use)
      // logic [63:0] addr_64;
      // addr_64 = is_4dw_hdr_reg ? {hdr_reg[95:64], hdr_reg[127:96]} : {32'h0, hdr_reg[95:64]};
      // cpl_cmd_o.data = {addr_64, addr_64, addr_64, addr_64};  // Replicate address
    end
    else begin  // TL_CFGRD
      cpl_cmd_o.data = '0;  // Placeholder - should come from cfg_space
      cpl_cmd_o.has_data = 1'b1;
      cpl_cmd_o.cpl_status = tl_pkg::CPL_SUCCESS;
    end
    
    if(cpl_cmd_ready_i) begin
      cpl_cmd_valid_o = 1'b1;
    end
  end
  else if(fsm_state == ST_ROUTE_PKT && pkt_type_reg == TL_OTHERS) begin
    // Unsupported request: Return UR (Unsupported Request) completion
    cpl_cmd_o.requester_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_cmd_o.tag          = hdr_reg[55:48];
    cpl_cmd_o.byte_count   = 12'd0;  // No data for UR
    cpl_cmd_o.lower_addr   = 7'd0;
    cpl_cmd_o.first_be     = first_be;
    cpl_cmd_o.last_be      = last_be;
    cpl_cmd_o.data         = '0;
    cpl_cmd_o.has_data     = 1'b0;
    cpl_cmd_o.cpl_status   = tl_pkg::CPL_UR;  // Unsupported Request
    
    if(cpl_cmd_ready_i) begin
      cpl_cmd_valid_o = 1'b1;
    end
  end
end

// ========== Config Request Output (ALREADY CORRECT) ==========
always_comb begin
  cfg_req_o = '0;
  cfg_req_valid_o = 1'b0;
  
  if (fsm_state == ST_ROUTE_PKT && (pkt_type_reg == TL_CFGRD || pkt_type_reg == TL_CFGWR)) begin
    cfg_req_o.is_read      = (pkt_type_reg == TL_CFGRD);
    cfg_req_o.requester_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cfg_req_o.tag          = hdr_reg[55:48];
    cfg_req_o.first_be     = first_be;
    cfg_req_o.last_be      = last_be;
    cfg_req_o.reg_num      = {hdr_reg[87:84], hdr_reg[95:90]};
    cfg_req_o.data         = (pkt_type_reg == TL_CFGWR) ? hdr_reg[127:96] : 32'd0;
    if(cfg_req_ready_i) begin
      cfg_req_valid_o = 1'b1;
    end
  end
end

always_comb begin
  cpl_o = '0;
  cpl_valid_o = 1'b0;

  if(fsm_state == ST_ROUTE_PKT && (pkt_type_reg == TL_CPL || pkt_type_reg == TL_CPLD)) begin
    cpl_o.sop = 1'b1;
    cpl_o.eop = (pkt_type_reg == TL_CPL) ? 1'b1 : (length_dw_reg == 10'd1) ? 1'b1 : 1'b0;
    cpl_o.completer_id = {hdr_reg[39:32], hdr_reg[47:40]};
    cpl_o.requester_id = {hdr_reg[71:64], hdr_reg[79:72]};
    cpl_o.tag          = hdr_reg[87:80];
    cpl_o.status       = hdr_reg[55:53];
    cpl_o.byte_count   = {hdr_reg[51:48], hdr_reg[63:56]};
    cpl_o.lower_addr   = hdr_reg[94:88];
    cpl_o.has_data     = (pkt_type_reg == TL_CPLD) ? 1'b1 : 1'b0;
    cpl_o.be           = (pkt_type_reg == TL_CPLD) ? {12'hFFF, first_be} : 16'hFFFF; // Full beat if no data
    cpl_o.data         = (pkt_type_reg == TL_CPLD) ? hdr_reg[127:96] : 32'd0;
    if(cpl_ready_i) begin
      cpl_valid_o = 1'b1;
    end
  end else if(fsm_state == ST_DATA_BEAT && pkt_type_reg == TL_CPLD && tl_rx_valid_i) begin
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
