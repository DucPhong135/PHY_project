module tl_cpl_engine 
import tl_pkg::*;
#(
  parameter int TAG_W = 8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // Completion from RX parser (cpl_rx_t includes tag, data, status, etc.)
  input  cpl_rx_t        cpl_i,
  input  logic                   cpl_valid_i,
  output logic                   cpl_ready_o,

  // Tag Table lookup interface
  output logic [TAG_W-1:0]       lookup_tag_o,
  output logic                   lookup_valid_o,
  input  logic                   lookup_ready_i,    // Always 1 (combinational lookup)
  
  input  logic [15:0]            lookup_req_id_i,   // From tag table
  input  logic [31:0]            lookup_addr_i,     // From tag table
  input  logic [9:0]             lookup_len_i,      // From tag table (in DWs)
  input  logic [2:0]             lookup_attr_i,     // From tag table

  // Tag Table free interface
  output logic [TAG_W-1:0]       free_tag_o,
  output logic                   free_valid_o,

  // Returned data to user application
  output logic [TAG_W-1:0]       usr_rtag_o,       // Tag (identifies which read request)
  output logic [31:0]            usr_raddr_o,      // Address requested
  output logic [127:0]           usr_rdata_o,      // Read data (128 bits = 4 DWs)
  output logic                   usr_rvalid_o,
  output logic                   usr_rsop_o,       // Start of read response
  output logic                   usr_reop_o,       // End of read response
  input  logic                   usr_rready_i
);

  // Completion processing state machine
  typedef enum logic [2:0] {
    IDLE    = 3'd0,  // Wait for completion from RX
    LOOKUP  = 3'd1,  // Query tag table for request metadata
    CHECK   = 3'd2,  // Validate lookup result
    STREAM  = 3'd3,  // Stream data to user (multi-beat capable)
    ERROR   = 3'd4   // Handle invalid completions
  } state_t;

  state_t state, next_state;

  // Registered completion data (latched in LOOKUP)
  cpl_rx_t cpl_reg;

  // lookup registers (latched in CHECK)
  logic [15:0]            lookup_req_id_reg;
  logic [31:0]            lookup_addr_reg;
  logic [9:0]             lookup_len_reg;
  logic [2:0]             lookup_attr_reg;


  // Beat tracking for multi-beat completions
  logic [9:0] beat_count;      // Current beat number
  logic [9:0] total_beats;     // Total beats expected (from tag table length)
  logic       last_beat;       // Flag for final beat


  logic [31:0] dw_buffer;      // Buffer for unaligned data (from previous beat)
  logic [127:0] aligned_data;   // Aligned data output for user

  // Calculate last beat flag
 assign last_beat = cpl_i.eop;

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state <= IDLE;
    end
    else begin
      state <= next_state;
    end
  end


  always_comb begin
    next_state = state;
      case (state)
        IDLE: begin
          if(cpl_valid_i) begin
            next_state = LOOKUP;
          end
          else begin
            next_state = IDLE;
          end
        end
        LOOKUP: begin
          if (lookup_ready_i) begin  // Wait for tag table
            next_state = CHECK;
          end
        end
        CHECK: begin
          if(lookup_req_id_reg == cpl_reg.requester_id && cpl_reg.status == CPL_SUCCESS) begin
            next_state = STREAM;
          end
          else begin
            next_state = ERROR;
          end
        end
        STREAM: begin
          if(last_beat && usr_rvalid_o && usr_rready_i) begin
            next_state = IDLE;
          end
          else begin
            next_state = STREAM;
          end
        end
        ERROR: begin
          // After error handling, return to IDLE
          next_state = IDLE;
        end
        default: begin
          next_state = IDLE;
        end
      endcase
  end

  always_comb begin
    cpl_ready_o = 1'b0;
    case (state)
      IDLE: begin
        cpl_ready_o = 1'b1;  // Ready to accept new completion
      end
      LOOKUP: begin
        // Latch completion, no RX needed
        cpl_ready_o = 1'b0;
      end
      STREAM: begin
        cpl_ready_o = usr_rready_i;  // Backpressure from user
      end
      default: begin
        cpl_ready_o = 1'b0;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      cpl_reg <= '0;
    end
    else begin
      if(state == IDLE && next_state == LOOKUP) begin
        cpl_reg <= cpl_i;
      end
    end
  end

  always_comb begin
    if(state == LOOKUP) begin
      lookup_tag_o   = cpl_i.tag;
      lookup_valid_o = 1'b1;
    end
    else begin
      lookup_tag_o   = '0;
      lookup_valid_o = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      lookup_req_id_reg <= '0;
      lookup_addr_reg   <= '0;
      lookup_len_reg    <= '0;
      lookup_attr_reg   <= '0;
    end
    else if(state == LOOKUP && next_state == CHECK) begin
      lookup_req_id_reg <= lookup_req_id_i;
      lookup_addr_reg   <= lookup_addr_i;
      lookup_len_reg    <= lookup_len_i;
      lookup_attr_reg   <= lookup_attr_i;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      beat_count  <= '0;
      total_beats <= '0;
      dw_buffer   <= '0;
    end
    else begin
        case (state)
          CHECK: begin
            if(lookup_req_id_reg == cpl_reg.requester_id && cpl_reg.status == CPL_SUCCESS) begin
              // Valid completion
              total_beats <= (lookup_len_reg - 10'd1 + 10'd3) >> 2;
              total_beats <= total_beats + 1;
              beat_count <= '0;
            end
            else begin
              // Invalid completion, handle error
            end
          end
          STREAM: begin
            if(usr_rvalid_o && usr_rready_i) begin
              if(!last_beat) begin
                beat_count <= beat_count + 10'd1;
              end

              if(!last_beat) begin
                // Buffer unaligned DW for next beat
                dw_buffer <= cpl_i.data[127:96];
              end
            end
          end
          default: begin
            beat_count <= '0;
            total_beats <= '0;
            dw_buffer <= '0;
          end
        endcase
      end
    end

  always_comb begin
    aligned_data = '0;
    if(state == STREAM) begin
        if (beat_count == 10'd0) begin
          // Beat 0: First DW from header (cpl_reg)
          // If only 1 DW total, just output it
          if (total_beats == 1) begin
            aligned_data = {96'h0, cpl_reg.data[31:0]};
          end 
          // If more DWs coming, merge first DW with next 3 DWs
          else begin
            aligned_data = {cpl_i.data[95:0], cpl_reg.data[31:0]};
            // aligned_data[31:0]   = DW0 (from header)
            // aligned_data[63:32]  = DW1 (from beat 1, bits [31:0])
            // aligned_data[95:64]  = DW2 (from beat 1, bits [63:32])
            // aligned_data[127:96] = DW3 (from beat 1, bits [95:64])
          end
        end 
        else begin
          // Beat 1+: Use buffered DW + current beat's lower 3 DWs
          aligned_data = {cpl_i.data[95:0], dw_buffer};
          // aligned_data[31:0]   = DW(n-1) (buffered from previous beat)
          // aligned_data[63:32]  = DW(n)   (from current beat, bits [31:0])
          // aligned_data[95:64]  = DW(n+1) (from current beat, bits [63:32])
          // aligned_data[127:96] = DW(n+2) (from current beat, bits [95:64])
        end
    end
  end

  assign usr_rdata_o  = aligned_data;
  assign usr_rtag_o   = cpl_reg.tag;
  assign usr_raddr_o  = lookup_addr_reg;
  assign usr_rsop_o   = (state == STREAM) && (beat_count == 10'd0);
  assign usr_reop_o   = (state == STREAM) && last_beat;
  assign usr_rvalid_o = (state == STREAM) && usr_rready_i && 
                        ((beat_count == 10'd0) || cpl_valid_i);
  
  assign free_tag_o   = cpl_reg.tag;
  assign free_valid_o = (state == STREAM) && last_beat && usr_rvalid_o && usr_rready_i;
endmodule
