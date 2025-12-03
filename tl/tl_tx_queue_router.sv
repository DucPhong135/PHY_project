module tl_tx_queue_router
  import tl_pkg::*;
#(
  parameter int QUEUE_DEPTH = 16
)(
  input  logic                    clk,
  input  logic                    rst_n,

  // Input from payload_mux
  input  tl_stream_t              pkt_i,
  input  logic                    pkt_valid_i,
  output logic                    pkt_ready_o,


  // Output to Posted queue
  output tl_stream_t              pkt_posted_o,
  output logic                    pkt_posted_valid_o,
  input  logic                    pkt_posted_ready_i,


  // Output to Non-Posted queue
  output tl_stream_t              pkt_np_o,
  output logic                    pkt_np_valid_o,
  input  logic                    pkt_np_ready_i

);


  // ========== Queue Type Selection ==========
  typedef enum logic [1:0] {
    QUEUE_POSTED = 2'd0,
    QUEUE_NP     = 2'd1,
    QUEUE_NONE   = 2'd2
  } queue_sel_e;

  queue_sel_e selected_queue;
  queue_sel_e locked_queue;    // Remember which queue for multi-beat packets
  logic       in_packet;        // High when routing data beats

  // ========== Decode Packet Type from Header (SOP) ==========
  logic [2:0] fmt;
  logic [4:0] pkt_type;
  
  assign fmt      = pkt_i.data[7:5];
  assign pkt_type = pkt_i.data[4:0];

  always_comb begin
    selected_queue = QUEUE_NONE;
    
    if (pkt_valid_i && pkt_i.sop) begin
      // Posted transactions (MWr)
      case({fmt, pkt_type})
        8'b010_00000, 8'b011_00000: begin
          selected_queue = QUEUE_POSTED;
        end

        // Non-Posted transactions (MRd)
        8'b000_00000, 8'b001_00000: begin
          selected_queue = QUEUE_NP;
        end
        8'b000_00100: begin
          selected_queue = QUEUE_NP;
        end
        8'b010_00100: begin
          selected_queue = QUEUE_POSTED;
        end
        default: begin
          selected_queue = QUEUE_NONE;
        end
      endcase
    end
  end

  // ========== Lock Queue Selection for Multi-Beat Packets ==========
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      locked_queue <= QUEUE_NONE;
      in_packet    <= 1'b0;
    end else begin
      if (pkt_valid_i && pkt_ready_o) begin
        if (pkt_i.sop && selected_queue == QUEUE_POSTED) begin
          // Start of new packet - lock to selected queue
          locked_queue <= selected_queue;
          in_packet    <= 1'b1;
        end else if (pkt_i.eop) begin
          // End of packet - release lock
          locked_queue <= QUEUE_NONE;
          in_packet    <= 1'b0;
        end
      end
    end
  end

  // ========== Route Packets (Header + Data Beats) ==========
    queue_sel_e active_queue;
  
  // Use locked queue for data beats, selected queue for SOP
  assign active_queue = in_packet ? locked_queue : selected_queue;

  always_comb begin
    pkt_posted_o            = '0;
    pkt_posted_valid_o      = 1'b0;
    
    pkt_np_o                = '0;
    pkt_np_valid_o          = 1'b0;
    
    
    pkt_ready_o             = pkt_posted_ready_i & pkt_np_ready_i; // Default to ready if no queue selected

    case (active_queue)
      QUEUE_POSTED: begin
        pkt_posted_o            = pkt_i;
        pkt_posted_valid_o      = pkt_valid_i;
        pkt_ready_o             = pkt_posted_ready_i;
      end
      
      QUEUE_NP: begin
        pkt_np_o                = pkt_i;
        pkt_np_valid_o          = pkt_valid_i;
        pkt_ready_o             = pkt_np_ready_i;
      end
    endcase
  end    
endmodule