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
  input  logic                   cpl_ready_i


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


typedef enum logic[2:0] {
  ST_IDLE,
  ST_DECODE_HDR,
  ST_ROUTE_MRD,
  ST_ROUTE_CFGRD,
  ST_ROUTE_MWR,
  ST_ROUTE_CFGWR,
  ST_ROUTE_CPL,
  ST_ROUTE_CPLD
} state_e;

state_e fsm_state, fsm_state_nxt;

tl_pkg::tl_stream_t current_pkt;

tl_pkg::tl_data_t memwr_reg;

logic[2:0] byte_en_first, byte_en_last;



always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    fsm_state <= ST_IDLE;
  end else begin
    fsm_state <= fsm_state_nxt;
  end
end


// Combinational header decode logic
always_comb begin
  // Default values
  pkt_type = TL_OTHERS;
  
  // Decode packet type from header (combinational)
  case(current_pkt.data[127:125]) // Format field
    3'b000: begin // 3DW header
      case(current_pkt.data[124:120]) // Type field
        5'b00000: pkt_type = TL_MRD;   // Memory Read
        5'b00100: pkt_type = TL_CFGRD; // Config Read
        5'b01010: pkt_type = TL_CPL;   // Completion
        default:  pkt_type = TL_OTHERS;
      endcase
    end
    3'b001: pkt_type = TL_MRD;         // 4DW Memory Read
    3'b010: begin // 3DW header with data
      case(current_pkt.data[124:120])
        5'b00000: pkt_type = TL_MWR;   // Memory Write
        5'b00100: pkt_type = TL_CFGWR; // Config Write
        5'b01010: pkt_type = TL_CPLD;  // Completion with Data
        default:  pkt_type = TL_OTHERS;
      endcase
    end
    3'b011: pkt_type = TL_MWR;         // 4DW Memory Write
    default: pkt_type = TL_OTHERS;
  endcase
end

// Sequential FSM state logic
always_comb begin
  case(fsm_state)
    ST_IDLE: begin
      if (tl_rx_valid_i) begin
        fsm_state_nxt = ST_DECODE_HDR;
      end else begin
        fsm_state_nxt = ST_IDLE;
      end
    end

    ST_DECODE_HDR: begin
      // Route based on decoded packet type (1 cycle decode)
      case (pkt_type)
        TL_MRD:    fsm_state_nxt = ST_ROUTE_MRD;
        TL_MWR:    fsm_state_nxt = ST_ROUTE_MWR;
        TL_CPL:    fsm_state_nxt = ST_ROUTE_CPL;
        TL_CPLD:   fsm_state_nxt = ST_ROUTE_CPLD;
        TL_CFGRD:  fsm_state_nxt = ST_ROUTE_CFGRD;
        TL_CFGWR:  fsm_state_nxt = ST_ROUTE_CFGWR;
        default:   fsm_state_nxt = ST_IDLE;
      endcase
    end

    ST_ROUTE_MRD: begin
      // Route MRd packet to completion generator
      if (cpl_cmd_ready_i) begin
        cpl_cmd_o <= /* construct cpl_gen_cmd_t from current_pkt */;
        cpl_cmd_valid_o <= 1'b1;
        if (current_pkt.last) begin
          fsm_state_nxt = ST_IDLE;
        end else begin
          fsm_state_nxt = ST_ROUTE_MRD; // stay in this state for more data
        end
      end else begin
        cpl_cmd_valid_o <= 1'b0;
        fsm_state_nxt = ST_ROUTE_MRD; // wait
      end
    end
  endcase
end

always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    current_pkt <= '0;
  end else if(fsm_state == IDLE && tl_tx_valid_i) begin
    current_pkt <= tl_rx_i;
  end
end


always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    tl_rx_ready_o <= 1'b1;
  end else begin
    if(fsm_state == IDLE && tl_tx_valid_i) begin
      tl_rx_ready_o <= 1'b1;
    end else begin
      tl_rx_ready_o <= 1'b0;
    end
  end
end


always_comb begin
  case(current_pkt.data[67:64])
    4'b1111: byte_en_first = 3'b100; // 4-byte aligned
    4'b1110: byte_en_first = 3'b011; // 4-byte aligned + 1 byte
    4'b1100: byte_en_first = 3'b010; // 4-byte aligned + 2 bytes
    4'b1000: byte_en_first = 3'b001; // 4-byte aligned + 3 bytes
    default: byte_en_first = 3'b000; // default to all bytes enabled
  endcase

  case(current_pkt.data[71:68])
    4'b1111: byte_en_last = 3'b100; // 4-byte aligned
    4'b1110: byte_en_last = 3'b011; // 4-byte aligned + 1 byte
    4'b1100: byte_en_last = 3'b010; // 4-byte aligned + 2 bytes
    4'b1000: byte_en_last = 3'b001; // 4-byte aligned + 3 bytes
    default: byte_en_last = 3'b000; // default to all bytes enabled
  endcase
end


always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    pkt_type <= TL_OTHERS;
  end
  else if(fsm_state == ST_DECODE_HDR) begin
    // Decode header to determine packet type
    case (current_pkt.data[127:125])
      3'b000, 3'b001: begin
        if(current_pkt.data[124:120] == 5'b00000) begin
          pkt_type <= TL_MRD; // Memory Read
          cpl_cmd_o.requester_id <= current_pkt.data[95:80];
          cpl_cmd_o.tag          <= current_pkt.data[79:72];
          cpl_cmd_o.byte_count   <= current_pkt.data[105:96]*32 + byte_en_last + byte_en_first - 4'd8; // in bytes
          cpl_cmd_o.has_data     <= 1'b1; // Completion with Data

          // Completion Status determination (UR if address out of range)
          if(current_pkt.data[127:125] == 3'b000) begin
            if(current_pkt.data[63:32] >= 32'h0000_FFFF) begin
              cpl_cmd_o.cpl_status <= tl_pkg::CPL_UR; // Unsupported Request
            end else begin
              cpl_cmd_o.cpl_status <= tl_pkg::CPL_SUCCESS; // Successful Completion
            end
          end else begin
            if(current_pkt.data[63:0] >= 64'h000_0000_0000_FFFF) begin
              cpl_cmd_o.cpl_status <= tl_pkg::CPL_UR; // Unsupported Request
            end else begin
              cpl_cmd_o.cpl_status <= tl_pkg::CPL_SUCCESS; // Successful Completion
            end
          end
          // Lower Address calculation based on alignment
          if(current_pkt.data[127:125] == 3'b000)
            case(current_pkt.data[67:64])
              4'b1111: cpl_cmd_o.lower_addr <= {current_pkt.data[38:34], 2'b00}; //
              4'b1110: cpl_cmd_o.lower_addr <= {current_pkt.data[38:34], 2'b01};
              4'b1100: cpl_cmd_o.lower_addr <= {current_pkt.data[38:34], 2'b10};
              4'b1000: cpl_cmd_o.lower_addr <= {current_pkt.data[38:34], 2'b11};
            endcase
          else if(current_pkt.data[127:125] = 3'b001)
            case(current_pkt.data[67:64])
              4'b1111: cpl_cmd_o.lower_addr <= {current_pkt.data[6:2], 2'b00}; //
              4'b1110: cpl_cmd_o.lower_addr <= {current_pkt.data[6:2], 2'b01};
              4'b1100: cpl_cmd_o.lower_addr <= {current_pkt.data[6:2], 2'b10};
              4'b1000: cpl_cmd_o.lower_addr <= {current_pkt.data[6:2], 2'b11};
            endcase
          
          cpl_cmd_o.data <= 256'd0; // Data will be filled by completion engine
      end

      else if(current_pkt.data[127:125] == 3'b000 && current_pkt.data[124:120] == 5'b00100) begin
          pkt_type              <= TL_CFGRD;         // Config Read
          cfg_req_o.is_read     <= 1'b1;             // Mark as read
          cfg_req_o.first_be    <= current_pkt.data[67:64];  // DW1[3:0] = FirstBE
          cfg_req_o.requester_id<= current_pkt.data[95:80];  // DW1[31:16]
          cfg_req_o.tag         <= current_pkt.data[79:72];  // DW1[15:8]

          // Register Number [5:0] = DW2[7:2]
          // Extended Register [3:0] = DW2[11:8]
          cfg_req_o.reg_num     <= {current_pkt.data[43:40],  // ExtReg[3:0]
                                    current_pkt.data[39:34]}; // Register[5:0]
          cfg_req_o.data        <= 32'd0;            // No data for read
      end

      else if(current_pkt.data[127:125] == 3'b000 && current_pkt.data[124:120] == 5'b01010) begin
          pkt_type <= TL_CPL; // Completion without Data
          cpl_o               <= '0;      // default zero
          cpl_o.sop           <= tl_rx_i.sop;
          cpl_o.eop           <= tl_rx_i.eop;
          cpl_o.be            <= 16'hFFFF; // for simplicity, all bytes valid unless decoded
          cpl_o.completer_id  <= current_pkt.data[63:48];   // DW1[31:16]
          cpl_o.status        <= current_pkt.data[47:45];   // DW1[15:13]
          cpl_o.byte_count    <= current_pkt.data[43:32];   // DW1[11:0]
          cpl_o.requester_id  <= current_pkt.data[95:80];   // DW2[31:16]
          cpl_o.tag           <= current_pkt.data[79:72];   // DW2[15:8]
          cpl_o.lower_addr    <= current_pkt.data[70:64];   // DW2[6:0]
          cpl_o.has_data      <= 1'b0;                     // No data
          cpl_o.data         <= 128'd0;                    // No data
      end
      else begin
          pkt_type <= TL_OTHERS;
      end
    end
    3'b010, 3'b011: begin
        if(current_pkt.data[124:120] == 5'b00000) begin
          pkt_type <= TL_MWR; // Memory Write
        end
        else if(current_pkt.data[127:125] == 3'b010 && current_pkt.data[124:120] == 5'b00100) begin
          pkt_type <= TL_CFGWR; // Config Write
        end
        else if(current_pkt.data[127:125] == 3'b010 && current_pkt.data[124:120] == 5'b01010) begin
          pkt_type <= TL_CPLD; // Completion with Data
        end
        else begin
          pkt_type <= TL_OTHERS;
        end
      end
    default: begin
        pkt_type <= TL_OTHERS;
    end
    endcase
  end
end






endmodule
