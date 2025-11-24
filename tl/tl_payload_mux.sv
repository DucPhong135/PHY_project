module tl_payload_mux 
  import tl_pkg::*;
#(
  parameter int STREAM_W = 128
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // Upstream write-data from user
  input  logic [127:0]            wdata_i,
  input  logic                    wdata_valid_i,
  output logic                    wdata_ready_o,
  output logic [1:0]              wdata_consumed_dw_o,  // ← NEW: How many DWs consumed

  // Header from hdr_gen
  input  logic [127:0]            hdr_i,
  input  logic                    hdr_valid_i,
  output logic                    hdr_ready_o,

  // Combined stream to queue router
  output tl_stream_t              tx_pkt_o,
  output logic                    tx_pkt_valid_o,
  input  logic                    tx_pkt_ready_i
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    HDR_BEAT  = 2'b01,
    DATA_BEAT = 2'b10
  } state_e;

  state_e state, next_state;

  // Payload tracking
  logic [11:0] total_data_dw;
  logic [11:0] data_dw_sent;
  logic [11:0] dw_remaining;

  logic [127:0] hdr_reg;
  
  assign dw_remaining = total_data_dw - data_dw_sent;

   // Latched metadata and byte enables from header
  logic [3:0] first_dw_be;
  logic [3:0] last_dw_be;
  logic is_first_data_beat;
  logic is_3dw_header;

  // Parse FirstDWBE and LastDWBE from TLP header
  // TLP Header Format (Byte 7): [7:4] = FirstDWBE, [3:0] = LastDWBE
  // In little-endian 128-bit format: bits [63:56] = byte 7
  logic [3:0] hdr_first_dw_be;
  logic [3:0] hdr_last_dw_be;
  
  assign hdr_first_dw_be = hdr_reg[63:60];
  assign hdr_last_dw_be  = hdr_reg[59:56];

  // DWs in current beat (1-4)
  logic [2:0] dw_this_beat;
  logic is_last_beat;
  
  // For 3DW header with data, first data beat takes 1 DW (packed with header)
  // For 4DW header or subsequent beats, take up to 4 DWs
  assign dw_this_beat = (is_3dw_header && is_first_data_beat) ? 12'd1 :
                        (dw_remaining >= 12'd4) ? 12'd4 : dw_remaining;
  assign is_last_beat = (data_dw_sent + dw_this_beat >= total_data_dw);

  // Byte enables for current beat
  logic [3:0] default_be_this_beat;
  logic [3:0] be_this_beat;
  
  assign default_be_this_beat = (dw_this_beat == 12'd4) ? 4'b1111 :
                                (dw_this_beat == 12'd3) ? 4'b0111 :
                                (dw_this_beat == 12'd2) ? 4'b0011 :
                                (dw_this_beat == 12'd1) ? 4'b0001 : 4'b0000;

  // Apply FirstDWBE on first data beat, LastDWBE on last beat, default for middle beats
  assign be_this_beat = is_first_data_beat ? first_dw_be :
                        is_last_beat       ? last_dw_be :
                                             4'b1111;

  // FSM state register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // FSM next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (hdr_valid_i)
          next_state = HDR_BEAT;
      end

      HDR_BEAT: begin
        if (tx_pkt_ready_i) begin
          if (total_data_dw == 12'd0 || hdr_reg[6] == 1'b0)
            next_state = IDLE;      // Header-only (MRd, CfgRd)
          else if (is_3dw_header && wdata_valid_i)
            next_state = DATA_BEAT; // 3DW header needs data for header beat
          else if(!is_3dw_header)
            next_state = DATA_BEAT; // Has payload (MWr, CfgWr)
        end
        else begin
          next_state = HDR_BEAT;
        end
      end

      DATA_BEAT: begin
        if (tx_pkt_ready_i && wdata_valid_i && is_last_beat) begin
          next_state = IDLE;
        end
        else begin
          next_state = DATA_BEAT;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      hdr_reg <= '0;
    end
    else begin
      if (hdr_valid_i && state == IDLE) begin
        hdr_reg <= hdr_i;
      end
    end
  end


  always_comb begin
    if(state == IDLE) begin
      hdr_ready_o = 1'b1;
    end
    else begin
      hdr_ready_o = 1'b0;
    end
  end

  

  always_comb begin
    total_data_dw = {hdr_reg[17:16], hdr_reg[31:24]}; //DW count from TLP header
    first_dw_be   = hdr_first_dw_be;  // Latch FirstDWBE from header
    last_dw_be    = hdr_last_dw_be;   // Latch LastDWBE from header
    is_3dw_header  = (hdr_reg[5] == 2'd0);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_dw_sent <= 12'd0;
    end
    else begin
      if (state == HDR_BEAT && next_state == DATA_BEAT) begin
        if (is_3dw_header && wdata_valid_i && tx_pkt_ready_i) begin
          data_dw_sent <= data_dw_sent + 12'd1; // First data DW packed with header
        end
      end
      else if (state == DATA_BEAT && next_state == DATA_BEAT) begin
        if (wdata_valid_i && tx_pkt_ready_i) begin
          data_dw_sent <= data_dw_sent + dw_this_beat;
        end
      end
      else if (state == DATA_BEAT && next_state == IDLE) begin
        if (wdata_valid_i && tx_pkt_ready_i) begin
          data_dw_sent <= data_dw_sent + dw_this_beat;
        end
      end
      else if (state == IDLE) begin
        data_dw_sent <= 12'd0;
      end
    end
  end

  always_latch begin
    if (is_3dw_header && state == HDR_BEAT) begin
      is_first_data_beat = 1'b1;
    end
    else if (state == DATA_BEAT && !is_3dw_header) begin
      if(data_dw_sent == 12'd0)
        is_first_data_beat = 1'b1;
      else
        is_first_data_beat = 1'b0;
    end
  end
  

  always_comb begin
    // Defaults
    tx_pkt_o              = '0;
    tx_pkt_valid_o        = 1'b0;
    wdata_ready_o         = 1'b0;

    case (state)
      HDR_BEAT: begin
        if (is_3dw_header && (total_data_dw != 12'd0)) begin
          if(hdr_reg[6] == 1'b1) begin // Write request with 3DW header
            tx_pkt_o.data       = {hdr_reg[95:0], wdata_i[31:0]};
            tx_pkt_o.sop        = 1'b1;
            tx_pkt_o.eop        = (total_data_dw == 12'd0 || total_data_dw == 12'd1);
            tx_pkt_o.be         = (total_data_dw == 12'd1) ? {first_dw_be, 4'b1111} : 4'b1111;
            tx_pkt_o.is_dllp    = 1'b0;
            tx_pkt_valid_o      = tx_pkt_ready_i && wdata_valid_i;
            
            wdata_ready_o       = tx_pkt_ready_i;
            wdata_consumed_dw_o   = 2'd1;  // ← Only 1 DW consumed
          end
          else if(hdr_reg[6] == 1'b0) begin // Read request with 3DW header
            tx_pkt_o.data       = {hdr_reg[95:0], 32'd0};
            tx_pkt_o.sop        = 1'b1;
            tx_pkt_o.eop        = 1'b1;
            tx_pkt_o.be         = 4'b1111;
            tx_pkt_o.is_dllp    = 1'b0;
            tx_pkt_valid_o      = tx_pkt_ready_i;
            wdata_consumed_dw_o   = 2'd0;  // ← No data consumed yet
          end
        end
        else begin
          // 4DW header
          if(hdr_i[6] == 1'b1) begin // Write request with 4DW header
            tx_pkt_o.data       = hdr_i;
            tx_pkt_o.sop        = 1'b1;
            tx_pkt_o.eop        = (total_data_dw == 12'd0);
            tx_pkt_o.be         = 4'b1111;
            tx_pkt_o.is_dllp    = 1'b0;
            tx_pkt_valid_o      = tx_pkt_ready_i;
            wdata_consumed_dw_o = 2'd0;  // ← No data consumed yet
          end
          else if(hdr_i[6] == 1'b0) begin // Read request with 4DW header
            tx_pkt_o.data       = hdr_i;
            tx_pkt_o.sop        = 1'b1;
            tx_pkt_o.eop        = 1'b1;
            tx_pkt_o.be         = 4'b1111;
            tx_pkt_o.is_dllp    = 1'b0;
            tx_pkt_valid_o      = tx_pkt_ready_i;
            wdata_consumed_dw_o = 2'd0;  // ← No data consumed yet
          end
        end
      end

      DATA_BEAT: begin
        tx_pkt_o.data       = wdata_i;
        tx_pkt_o.sop        = 1'b0;
        tx_pkt_o.eop        = is_last_beat;
        tx_pkt_o.be         = be_this_beat;
        tx_pkt_o.is_dllp    = 1'b0;
        tx_pkt_valid_o      = wdata_valid_i && tx_pkt_ready_i;
        
        wdata_ready_o       = tx_pkt_ready_i;
        wdata_consumed_dw_o = dw_this_beat[1:0];  // ← 1-4 DWs consumed
      end

      default: begin
        // Keep defaults
      end
    endcase
  end

endmodule