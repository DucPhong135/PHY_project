module tl_cpl_gen 
import tl_pkg::*;
#(
  parameter int TAG_W = 8,
  parameter int MAX_CPLD_PAYLOAD = 8, // in DWs
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
  input  logic                   credit_data_ok_i,

  // Combined completion output (header + data in tl_stream_t format)
  output tl_pkg::tl_stream_t     cpl_pkt_o,
  output logic                   cpl_pkt_valid_o,
  input  logic                   cpl_pkt_ready_i
);


typedef enum logic[2:0] {
  FSM_IDLE,
  FSM_GEN_HDR,
  FSM_SEND_HDR,
  FSM_WAIT_CRED,
  FSM_SEND_DATA
} fsm_state_t;

fsm_state_t fsm_state, fsm_next;

tl_pkg::cpl_gen_cmd_t cpl_cmd_reg;

// Beat counter for multi-beat data transfers
logic [7:0] beat_count;  // Extended to 8 bits to support up to 255 beats
logic [7:0] total_beats; // Extended to 8 bits for max payload support

// Internal header register
logic [127:0] cpl_hdr_reg;


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
    // Default assignments
    fsm_next = fsm_state;

    case (fsm_state)
      FSM_IDLE: begin
        if (cpl_cmd_valid_i) begin
          fsm_next = FSM_GEN_HDR;
        end
      end

      FSM_GEN_HDR: begin
        // Decode the command and decide next steps
       case (cpl_cmd_reg.cpl_status)
                CPL_SUCCESS: begin
                    if(cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i && credit_data_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end 
                    else if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_GEN_HDR; // wait until credits are available
                    end
                end
                CPL_UR: begin
                    if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if( credit_hdr_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end
                    else begin
                        fsm_next = FSM_SEND_HDR; // wait until credits are available
                    end
                end
            endcase
      end
      FSM_SEND_HDR: begin
         case (cpl_cmd_reg.cpl_status)
                CPL_SUCCESS: begin
                    if(cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i && credit_data_ok_i) begin
                            fsm_next = FSM_SEND_DATA; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_SEND_HDR; // wait until credits are available
                        end
                    end 
                    else if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i) begin
                            fsm_next = FSM_IDLE; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_SEND_HDR; // wait until credits are available
                    end
                end
                CPL_UR: begin
                    if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if( credit_hdr_ok_i) begin
                            fsm_next = FSM_IDLE; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end
                    else begin
                        fsm_next = FSM_SEND_HDR; // wait until credits are available
                    end
                end
            endcase
      end
      FSM_WAIT_CRED: begin
       case (cpl_cmd_reg.cpl_status)
                CPL_SUCCESS: begin
                    if(cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i && credit_data_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For write, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end 
                    else if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if (credit_hdr_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end else begin
                        fsm_next = FSM_WAIT_CRED; // wait until credits are available
                    end
                end
                CPL_UR: begin
                    if(!cpl_cmd_reg.has_data && cpl_pkt_ready_i) begin
                        if(credit_hdr_ok_i) begin
                            fsm_next = FSM_SEND_HDR; // For read, go back to IDLE after sending header
                        end else begin
                            fsm_next = FSM_WAIT_CRED; // wait until credits are available
                        end
                    end
                    else begin
                        fsm_next = FSM_WAIT_CRED; // wait until credits are available
                    end
                end
            endcase
      end
      FSM_SEND_DATA: begin
        if(cpl_pkt_valid_o && cpl_pkt_ready_i) begin
          // Check if this is the last beat
          if(beat_count == total_beats - 1) begin
            fsm_next = FSM_IDLE;  // All beats sent
          end
          else begin
            fsm_next = FSM_SEND_DATA;  // More beats to send
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
    if (cpl_cmd_valid_i && cpl_cmd_ready_o) begin
      cpl_cmd_reg <= cpl_cmd_i;
      // Calculate data beats needed (excluding header beat)
      // Header beat includes 3DW header + first data DW (if has_data)
      // Remaining data needs: (byte_count - 4) / 16 beats
      if(cpl_cmd_i.has_data && cpl_cmd_i.byte_count > 4) begin
        // Calculate additional beats needed for remaining data
        // After packing first DW with header, remaining bytes need ceil((byte_count-4)/16)
        total_beats <= ((cpl_cmd_i.byte_count - 12'd4 + 12'd15) >> 4);  // Divide by 16, ceiling
      end
      else begin
        total_beats <= 8'd0;  // No additional data beats needed
      end
    end
  end
end

// Beat counter - tracks current beat being sent
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    beat_count <= 8'd0;
  end else begin
    if (fsm_state == FSM_IDLE) begin
      beat_count <= 8'd0;  // Reset on IDLE
    end
    else if (fsm_state == FSM_SEND_DATA && cpl_pkt_valid_o && cpl_pkt_ready_i) begin
      beat_count <= beat_count + 8'd1;  // Increment on each successful transfer
    end
  end
end

// Calculate DW count with ceiling (round up)
logic [9:0] DW_count = (cpl_cmd_reg.byte_count + 12'd3) >> 2;

// Header Generation Logic
always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
    cpl_hdr_reg <= '0;
  end else begin
    if(fsm_state == FSM_GEN_HDR) begin
      // Common fields for both CPL and CPLD
      if(cpl_cmd_reg.cpl_status == 3'd0) begin
        // Set format field based on whether completion has data
        if(cpl_cmd_reg.has_data) begin
          cpl_hdr_reg[7:0] <= 8'h4A; // CPLD (Completion with Data)
        end else begin
          cpl_hdr_reg[7:0] <= 8'h0A; // CPL (Completion without Data)
        end
        
        // Common header fields
        cpl_hdr_reg[15:8] <= 8'h00; // Traffic Class 0, No Attributes
        cpl_hdr_reg[23:16] <= {6'b0, DW_count[9:8]}; // Length MSBs
        cpl_hdr_reg[31:24] <= DW_count[7:0]; // Length LSBs
        cpl_hdr_reg[39:32] <= requester_id_i[15:8]; // Completer ID from command
        cpl_hdr_reg[47:40] <= requester_id_i[7:0]; // Completer ID from command
        cpl_hdr_reg[55:53] <= cpl_cmd_reg.cpl_status; // Completion Status
        cpl_hdr_reg[52] <= 1'b0; // BCM
        cpl_hdr_reg[51:48] <= cpl_cmd_reg.byte_count[11:8]; // Byte Count MSBs
        cpl_hdr_reg[63:56] <= cpl_cmd_reg.byte_count[7:0]; // Byte Count LSBs
        cpl_hdr_reg[71:64] <= cpl_cmd_reg.requester_id[15:8]; // Requester ID from command
        cpl_hdr_reg[79:72] <= cpl_cmd_reg.requester_id[7:0]; // Requester ID from command
        cpl_hdr_reg[87:80] <= cpl_cmd_reg.tag; // Tag from command
        cpl_hdr_reg[94:88] <= cpl_cmd_reg.lower_addr; // Lower Address from command
        cpl_hdr_reg[95] <= 1'b0; // Reserved
        cpl_hdr_reg[127:96] <= 32'h0000_0000; // Reserved
      end
    else if(cpl_cmd_reg.cpl_status == 3'd1) begin
      // Unsupported Completion Status - UR (always without data)
      cpl_hdr_reg[7:0] <= 8'h0A; // CPL
      cpl_hdr_reg[15:8] <= 8'h00; // Traffic Class 0, No Attributes
      cpl_hdr_reg[23:16] <= {6'b0, DW_count[9:8]}; // Length MSBs
      cpl_hdr_reg[31:24] <= DW_count[7:0]; // Length LSBs
      cpl_hdr_reg[39:32] <= requester_id_i[15:8]; // Completer ID from command
      cpl_hdr_reg[47:40] <= requester_id_i[7:0]; // Completer ID from command
      cpl_hdr_reg[55:53] <= cpl_cmd_reg.cpl_status; // Completion Status
      cpl_hdr_reg[52] <= 1'b0; // BCM
      cpl_hdr_reg[51:48] <= cpl_cmd_reg.byte_count[11:8]; // Byte Count MSBs
      cpl_hdr_reg[63:56] <= cpl_cmd_reg.byte_count[7:0]; // Byte Count LSBs
      cpl_hdr_reg[71:64] <= cpl_cmd_reg.requester_id[15:8]; // Requester ID from command
      cpl_hdr_reg[79:72] <= cpl_cmd_reg.requester_id[7:0]; // Requester ID from command
      cpl_hdr_reg[87:80] <= cpl_cmd_reg.tag; // Tag from command
      cpl_hdr_reg[94:88] <= cpl_cmd_reg.lower_addr; // Lower Address from command
      cpl_hdr_reg[95] <= 1'b0; // Reserved
      cpl_hdr_reg[127:96] <= 32'h0000_0000; // Reserved
    end
    else if(cpl_cmd_reg.cpl_status == 3'd2) begin
      // Configuration Request Retry Status - CRS (always without data)
      cpl_hdr_reg[7:0] <= 8'h0A; // CPL
      cpl_hdr_reg[15:8] <= 8'h00; // Traffic Class 0, No Attributes
      cpl_hdr_reg[23:16] <= {6'b0, DW_count[9:8]}; // Length MSBs
      cpl_hdr_reg[31:24] <= DW_count[7:0]; // Length LSBs
      cpl_hdr_reg[39:32] <= requester_id_i[15:8]; // Completer ID from command
      cpl_hdr_reg[47:40] <= requester_id_i[7:0]; // Completer ID from command
      cpl_hdr_reg[55:53] <= cpl_cmd_reg.cpl_status; // Completion Status
      cpl_hdr_reg[52] <= 1'b0; // BCM
      cpl_hdr_reg[51:48] <= cpl_cmd_reg.byte_count[11:8]; // Byte Count MSBs
      cpl_hdr_reg[63:56] <= cpl_cmd_reg.byte_count[7:0]; // Byte Count LSBs
      cpl_hdr_reg[71:64] <= cpl_cmd_reg.requester_id[15:8]; // Requester ID from command
      cpl_hdr_reg[79:72] <= cpl_cmd_reg.requester_id[7:0]; // Requester ID from command
      cpl_hdr_reg[87:80] <= cpl_cmd_reg.tag; // Tag from command
      cpl_hdr_reg[94:88] <= cpl_cmd_reg.lower_addr; // Lower Address from command
      cpl_hdr_reg[95] <= 1'b0; // Reserved
      cpl_hdr_reg[127:96] <= 32'h0000_0000; // Reserved
    end
    end
  end
end


// Combined output packet - combines header and data into tl_stream_t format
always_comb begin
  cpl_pkt_o = '0;
  
  case(fsm_state)
    FSM_SEND_HDR: begin
      // Completion headers are 3DW (12 bytes = 96 bits)
      // Pack 3DW header + first data DW in the 128-bit beat
      cpl_pkt_o.data[95:0] = cpl_hdr_reg[95:0];  // 3DW header
      
      if(cpl_cmd_reg.has_data) begin
        // Pack first data DW at bits [127:96]
        cpl_pkt_o.data[127:96] = cpl_cmd_reg.data[31:0];
        cpl_pkt_o.sop = 1'b1;
        cpl_pkt_o.eop = (total_beats == 0);  // EOP if only header + 1 DW
        cpl_pkt_o.be = (total_beats == 0) ? cpl_cmd_reg.first_be : 4'hF;
        cpl_pkt_o.is_dllp = 1'b0;
      end
      else begin
        // No data, header only
        cpl_pkt_o.data[127:96] = 32'h0;
        cpl_pkt_o.sop = 1'b1;
        cpl_pkt_o.eop = 1'b1;  // Header-only completion
        cpl_pkt_o.be = 4'hF;  // All 4 DWs valid (header is 3DW, but aligned in 4DW beat)
        cpl_pkt_o.is_dllp = 1'b0;
      end
    end
    
    FSM_SEND_DATA: begin
      // Send remaining data beats
      // Note: First DW already sent with header, so start from data[63:32]
      if(beat_count == 0) begin
        // First data beat: DW1, DW2, DW3, DW4 from data[159:32]
        cpl_pkt_o.data = cpl_cmd_reg.data[159:32];
        cpl_pkt_o.sop = 1'b0;
        cpl_pkt_o.eop = (total_beats == 1);  // EOP if only 1 more beat
        cpl_pkt_o.be = (total_beats == 1) ? cpl_cmd_reg.last_be : 4'hF;
        cpl_pkt_o.is_dllp = 1'b0;
      end
      else if(beat_count == 1) begin
        // Second data beat: remaining DWs from data[255:160]
        cpl_pkt_o.data[95:0] = cpl_cmd_reg.data[255:160];
        cpl_pkt_o.data[127:96] = 32'h0;  // Pad if needed
        cpl_pkt_o.sop = 1'b0;
        cpl_pkt_o.eop = 1'b1;  // Last beat
        cpl_pkt_o.be = cpl_cmd_reg.last_be;
        cpl_pkt_o.is_dllp = 1'b0;
      end
      else begin
        // For multi-beat transfers > 2 (would need streaming memory interface)
        cpl_pkt_o.data = cpl_cmd_reg.data[159:32];  // Repeat pattern for now
        cpl_pkt_o.sop = 1'b0;
        cpl_pkt_o.eop = (beat_count == total_beats - 1);
        cpl_pkt_o.be = (beat_count == total_beats - 1) ? cpl_cmd_reg.last_be : 4'hF;
        cpl_pkt_o.is_dllp = 1'b0;
      end
    end
    
    default: begin
      cpl_pkt_o = '0;
    end
  endcase
end

// Valid output - combinational, waits for ready to be high
always_comb begin
  cpl_pkt_valid_o = 1'b0;
  
  if (fsm_state == FSM_SEND_HDR) begin
    // Header beat is valid when ready is high AND credits are available
    if (cpl_cmd_reg.has_data) begin
      cpl_pkt_valid_o = cpl_pkt_ready_i && credit_hdr_ok_i && credit_data_ok_i;
    end else begin
      cpl_pkt_valid_o = cpl_pkt_ready_i && credit_hdr_ok_i;
    end
  end
  else if (fsm_state == FSM_SEND_DATA) begin
    // Data beats are valid when ready is high AND data credits available
    cpl_pkt_valid_o = cpl_pkt_ready_i && credit_data_ok_i;
  end
end
endmodule
