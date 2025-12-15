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
  input  logic [63:0]            lookup_addr_i,     // From tag table
  input  logic [9:0]             lookup_len_i,      // From tag table (in DWs)
  input  logic [2:0]             lookup_attr_i,     // From tag table
  input  logic [2:0]             lookup_fmt_i,      // From tag table
  input  logic [4:0]             lookup_pkt_type_i, // From tag table
  input  logic [3:0]             lookup_first_be_i,
  input  logic [3:0]             lookup_last_be_i,

  input  logic [7:0]             lookup_bus_number_i,
  input  logic [4:0]             lookup_device_number_i,
  input  logic [2:0]             lookup_function_number_i,

  // Tag Table free interface
  output logic [TAG_W-1:0]       free_tag_o,
  output logic                   free_valid_o,

  // Returned data to user application
  output logic [63:0]            usr_read_rp_addr_o,       // Address of read
  output logic [9:0]             usr_read_rp_length_o,     // Length in DWs
  output logic [3:0]             usr_first_be_o,         // First byte enable
  output logic [3:0]             usr_last_be_o,          // Last byte enable
  output logic                   usr_read_rp_valid_o,
  input  logic                   usr_read_rp_ready_i,

  output logic [31:0]           usr_rdata_o,      // Read data
  output logic                   usr_reop_o,       // End of read response
  output logic                   usr_rvalid_o,
  input  logic                   usr_rready_i,

  // ─────────────────────────────────────────────────────────────
  // Config Completion Interface (for verification)
  // ─────────────────────────────────────────────────────────────
  
  // Config Read Completion
  output logic [TAG_W-1:0]       cfg_rd_tag_o,     // Tag of config read request
  output logic [31:0]            cfg_rd_data_o,    // Config read data (1 DW)
  output logic [2:0]             cfg_rd_status_o,  // Completion status
  output logic [7:0]             cfg_rd_bus_number_o,
  output logic [4:0]             cfg_rd_device_number_o,
  output logic [2:0]             cfg_rd_function_number_o,
  output logic                   cfg_rd_valid_o,   // Config read completion valid
  input  logic                   cfg_rd_ready_i,   // Config read completion ready
  
  // Config Write Completion
  output logic [TAG_W-1:0]       cfg_wr_tag_o,     // Tag of config write request
  output logic [2:0]             cfg_wr_status_o,  // Completion status
  output logic [7:0]             cfg_wr_bus_number_o,
  output logic [4:0]             cfg_wr_device_number_o,
  output logic [2:0]             cfg_wr_function_number_o,
  output logic                   cfg_wr_valid_o,   // Config write completion valid
  input  logic                   cfg_wr_ready_i    // Config write completion ready
);

  // Completion processing state machine
  typedef enum logic [2:0] {
    IDLE    = 3'd0,  // Wait for completion from RX
    LOOKUP  = 3'd1,  // Query tag table for request metadata
    CHECK   = 3'd2,  // Validate lookup result
    SEND_READ_HDR = 3'd3,  // Stream data to user (multi-beat capable)
    SEND_READ_DATA = 3'd4,  // Stream data to user (multi-beat capable)
    CFG_CPL  = 3'd5,  // Handle config completions
    ERROR   = 3'd6   // Handle invalid completions
  } state_t;

  state_t state, next_state;

  // Registered completion data (latched in LOOKUP)
  cpl_rx_t cpl_reg;

  // lookup registers (latched in CHECK)
  logic [15:0]            lookup_req_id_reg;
  logic [63:0]            lookup_addr_reg;
  logic [9:0]             lookup_len_reg;
  logic [2:0]             lookup_attr_reg;
  logic [2:0]             lookup_fmt_reg;
  logic [4:0]             lookup_pkt_type_reg;
  logic [3:0]             lookup_first_be_reg;
  logic [3:0]             lookup_last_be_reg;
  logic [7:0]             lookup_bus_number_reg;
  logic [4:0]             lookup_device_number_reg;
  logic [2:0]             lookup_function_number_reg;


  // Beat tracking for multi-beat completions
  logic [9:0] dw_count;        // Current DW number being output
  logic [9:0] total_dw;        // Total DWs to output
  logic       last_dw;         // Flag for final DW


  // Data buffer to hold incoming 128-bit data
  logic [127:0] data_buffer;   // Buffer for completion data
  logic         buffer_valid;  // Buffer has valid data
  logic [1:0]   buffer_idx;    // Index within buffer (0-3)

  logic [31:0] current_dw;     // Current DW to output
  logic [3:0]  current_be;     // Current byte enable


  logic is_cfg_req;
  assign is_cfg_req = (lookup_pkt_type_reg == 5'b00100);

  // Calculate last DW flag
  assign last_dw = (dw_count == total_dw - 10'd1);

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
            if(is_cfg_req) begin
              next_state = CFG_CPL;  // Config completions handled separately
            end
            else begin
              if(cpl_reg.lower_addr == lookup_addr_reg[6:0]) begin
                next_state = SEND_READ_HDR;
              end
              else begin
                next_state = ERROR;
              end
            end
          end
          else begin
            next_state = ERROR;
          end
        end
        SEND_READ_HDR: begin
          if(usr_read_rp_ready_i && usr_read_rp_valid_o) begin
            next_state = SEND_READ_DATA;
          end
          else begin
            next_state = SEND_READ_HDR;
          end
        end
        SEND_READ_DATA: begin
          if(last_dw && usr_rvalid_o && usr_rready_i) begin
            next_state = IDLE;
          end
          else begin
            next_state = SEND_READ_DATA;
          end
        end
        CFG_CPL: begin
          if (is_cfg_rd_cpl && cfg_rd_ready_i) begin
            next_state = IDLE;
          end
          else if (is_cfg_wr_cpl && cfg_wr_ready_i) begin
            next_state = IDLE;
          end
          else begin
            next_state = CFG_CPL;
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

  // cpl_ready_o - request new data when buffer exhausted
  always_comb begin
    cpl_ready_o = 1'b0;
    case (state)
      IDLE: begin
        cpl_ready_o = 1'b1;  // Ready to accept new completion
      end
      SEND_READ_DATA: begin
        // Ready to accept next chunk when:
        // 1. About to finish current buffer (idx==3) and user accepts current DW, OR
        // 2. Buffer is invalid (waiting for data)
        cpl_ready_o = (need_new_chunk) || !buffer_valid;
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
      lookup_tag_o   = cpl_reg.tag;
      lookup_valid_o = 1'b1;
    end
    else begin
      lookup_tag_o   = '0;
      lookup_valid_o = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      lookup_req_id_reg   <= '0;
      lookup_addr_reg     <= '0;
      lookup_len_reg      <= '0;
      lookup_attr_reg     <= '0;
      lookup_fmt_reg      <= '0;
      lookup_pkt_type_reg <= '0;
      lookup_first_be_reg <= '0;
      lookup_last_be_reg  <= '0;
      lookup_bus_number_reg     <= '0;
      lookup_device_number_reg  <= '0;
      lookup_function_number_reg<= '0;
    end
    else if(state == LOOKUP && next_state == CHECK) begin
      lookup_req_id_reg   <= lookup_req_id_i;
      lookup_addr_reg     <= lookup_addr_i;
      lookup_len_reg      <= lookup_len_i;
      lookup_attr_reg     <= lookup_attr_i;
      lookup_fmt_reg      <= lookup_fmt_i;
      lookup_pkt_type_reg <= lookup_pkt_type_i;
      lookup_first_be_reg <= lookup_first_be_i;
      lookup_last_be_reg  <= lookup_last_be_i;
      lookup_bus_number_reg     <= lookup_bus_number_i;
      lookup_device_number_reg  <= lookup_device_number_i;
      lookup_function_number_reg<= lookup_function_number_i;
    end
  end


  always_comb begin
    usr_read_rp_addr_o = lookup_addr_reg;
    usr_read_rp_length_o = lookup_len_reg;
    usr_first_be_o    = lookup_first_be_reg;
    usr_last_be_o     = lookup_last_be_reg;
    usr_read_rp_valid_o = (state == SEND_READ_HDR) && (usr_read_rp_ready_i);
  end

  logic need_new_chunk;
  logic chunk_loaded;

  assign need_new_chunk = (state == SEND_READ_DATA) && (buffer_idx == 2'd3) && !last_dw;
  assign chunk_loaded   = need_new_chunk && cpl_valid_i && cpl_ready_o;


always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      dw_count     <= '0;
      total_dw     <= '0;
      data_buffer  <= '0;
      buffer_valid <= '0;
      buffer_idx   <= '0;
    end
    else begin
      case (state)
        CHECK: begin
          if(lookup_req_id_reg == cpl_reg.requester_id && cpl_reg.status == CPL_SUCCESS && !is_cfg_req) begin
            // Valid memory read completion - initialize
            total_dw     <= lookup_len_reg;
            dw_count     <= '0;
            // First DW comes from cpl_reg.data[127:96]
            data_buffer  <= {cpl_reg.data[31:0], 96'b0};
            buffer_valid <= 1'b1;
            buffer_idx   <= 2'd3;
          end
          else begin
            dw_count     <= '0;
            total_dw     <= '0;
            buffer_valid <= '0;
            buffer_idx   <= '0;
          end
        end
        
        SEND_READ_DATA: begin
          if(usr_rvalid_o && usr_rready_i) begin
            // DW accepted, move to next
            dw_count <= dw_count + 10'd1;
            
            if (!last_dw) begin
              // More DWs to send
              if (buffer_idx == 2'd3) begin
                // Need to load next 128-bit chunk from cpl_i
                // Wait for valid data from RX
                if (cpl_valid_i && cpl_ready_o) begin
                  data_buffer  <= cpl_i.data;
                  buffer_idx   <= 2'd0;
                  buffer_valid <= 1'b1;
                end
                else begin
                  // No valid data yet - mark buffer invalid
                  buffer_valid <= 1'b0;
                end
              end
              else begin
                buffer_idx <= buffer_idx + 2'd1;
              end
            end
          end
          else if (!buffer_valid && cpl_valid_i) begin
            // Buffer was invalid, now we have new data
            data_buffer  <= cpl_i.data;
            buffer_idx   <= 2'd0;
            buffer_valid <= 1'b1;
          end
        end
        
        default: begin
          dw_count     <= dw_count;
          total_dw     <= total_dw;
          data_buffer  <= data_buffer;
          buffer_valid <= buffer_valid;
          buffer_idx   <= buffer_idx;
        end
      endcase
    end
  end

  always_comb begin
    if (dw_count == 10'd0) begin
      // First DW - use first_be
      current_be = lookup_first_be_reg;
    end
    else if (last_dw) begin
      // Last DW - use last_be
      current_be = lookup_last_be_reg;
    end
    else begin
      // Middle DWs - all bytes enabled
      current_be = 4'b1111;
    end
  end

  logic [31:0] selected_dw;
  
  always_comb begin
    // Extract DW from buffer based on index
    // buffer_idx=3 -> bits [127:96]
    // buffer_idx=2 -> bits [95:64]
    // buffer_idx=1 -> bits [63:32]
    // buffer_idx=0 -> bits [31:0]
    case (buffer_idx)
      2'd3: selected_dw = data_buffer[127:96];
      2'd2: selected_dw = data_buffer[95:64];
      2'd1: selected_dw = data_buffer[63:32];
      2'd0: selected_dw = data_buffer[31:0];
    endcase
  end

  // Output with byte enable masking
  always_comb begin
    usr_rdata_o  = selected_dw & {{8{current_be[3]}}, 
                                   {8{current_be[2]}}, 
                                   {8{current_be[1]}}, 
                                   {8{current_be[0]}}};
    usr_reop_o   = last_dw;
    usr_rvalid_o = (state == SEND_READ_DATA) && buffer_valid && usr_rready_i;
  end




  logic is_cfg_rd_cpl;
  assign is_cfg_rd_cpl = is_cfg_req && (lookup_fmt_reg == 3'b000); // 3'b000 = Read
  logic is_cfg_wr_cpl;
  assign is_cfg_wr_cpl = is_cfg_req && (lookup_fmt_reg == 3'b010); // 3'b010 = Write

  assign cfg_rd_tag_o    = cpl_reg.tag;
  assign cfg_rd_data_o   = cpl_reg.data[31:0];  // Config read returns 1 DW
  assign cfg_rd_status_o = cpl_reg.status;
  assign cfg_rd_bus_number_o     = lookup_bus_number_reg;
  assign cfg_rd_device_number_o  = lookup_device_number_reg;
  assign cfg_rd_function_number_o= lookup_function_number_reg;
  assign cfg_rd_valid_o  = (state == CFG_CPL) && (is_cfg_rd_cpl);

  assign cfg_wr_tag_o    = cpl_reg.tag;
  assign cfg_wr_status_o = cpl_reg.status;
  assign cfg_wr_bus_number_o     = lookup_bus_number_reg;
  assign cfg_wr_device_number_o  = lookup_device_number_reg;
  assign cfg_wr_function_number_o= lookup_function_number_reg;
  assign cfg_wr_valid_o  = (state == CFG_CPL) && (is_cfg_wr_cpl);


  assign free_tag_o   = cpl_reg.tag;
  assign free_valid_o = ((state == SEND_READ_DATA) && last_dw && usr_rvalid_o && usr_rready_i) ||
                        ((state == CFG_CPL) && cfg_rd_valid_o && cfg_rd_ready_i) ||
                        ((state == CFG_CPL) && cfg_wr_valid_o && cfg_wr_ready_i);
endmodule
