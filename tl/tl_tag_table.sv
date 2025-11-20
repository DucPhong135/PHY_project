module tl_tag_table #(
  parameter int TAG_W   = 8,
  parameter int DEPTH   = 1<<8
)(
  input  logic                   clk,
  input  logic                   rst_n,

  // =================================================
  // Allocate request (from hdr_gen for MemRd/CfgRd)
  // =================================================
  input  logic                   alloc_req_i,
  output logic [TAG_W-1:0]       alloc_tag_o,
  output logic                   alloc_gnt_o,

  // Metadata to store for allocated Tag
  input  logic [15:0]            alloc_req_id_i,   // Requester ID
  input  logic [31:0]            alloc_addr_i,     
  input  logic [9:0]             alloc_len_i,      // Length in DWs
  input  logic [2:0]             alloc_attr_i,     // Attributes (RO/NS etc.)

  // =================================================
  // Lookup for Completion engine
  // =================================================
  input  logic [TAG_W-1:0]       lookup_tag_i,     // Which tag to read
  input  logic                   lookup_valid_i,   // Assert to read metadata
  output logic                   lookup_ready_o,   // Assert when metadata is valid

  output logic [15:0]            cpl_req_id_o,     // Requester ID
  output logic [31:0]            cpl_addr_o,       // Lower Address
  output logic [9:0]             cpl_len_o,        // Length in DWs
  output logic [2:0]             cpl_attr_o,       // Attributes

  // =================================================
  // Free tag (from completion engine after CplD sent)
  // =================================================
  input  logic [TAG_W-1:0]       free_tag_i,
  input  logic                   free_valid_i
);


  logic  [TAG_W-1:0] free_list [0:DEPTH-1];
  logic [TAG_W-1:0] free_count;
  logic [TAG_W-1:0] free_head;
  logic [TAG_W-1:0] free_tail;

  typedef struct packed {
    logic        valid;
    logic [15:0] requester_id;
    logic [31:0] addr;
    logic [9:0]  length;
    logic [2:0]  attr;
  } tag_ctx_t;

  tag_ctx_t ctx_table [0:DEPTH-1];

  // Combinational allocation output
  assign alloc_tag_o = free_list[free_head];
  assign alloc_gnt_o = (free_count > 0);

  // Combined free list and context table management
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      // Initialize free list with sequential tag values
      for(int i = 0; i < DEPTH; i++) begin
        free_list[i] <= i[TAG_W-1:0];
        ctx_table[i].valid <= 1'b0;
      end
      free_count <= DEPTH[TAG_W-1:0];
      free_head  <= '0;
      free_tail  <= DEPTH[TAG_W-1:0] - 1'b1;
    end else begin
      // Handle simultaneous allocation and free
      case ({alloc_req_i && alloc_gnt_o, free_valid_i})
        2'b10: begin  // Only allocation
          // Update free list pointers
          free_head <= (free_head == DEPTH[TAG_W-1:0] - 1'b1) ? '0 : free_head + 1'b1;
          free_count <= free_count - 1'b1;
          
          // Store metadata in context table
          ctx_table[alloc_tag_o].valid        <= 1'b1;
          ctx_table[alloc_tag_o].requester_id <= alloc_req_id_i;
          ctx_table[alloc_tag_o].addr         <= alloc_addr_i;
          ctx_table[alloc_tag_o].length       <= alloc_len_i;
          ctx_table[alloc_tag_o].attr         <= alloc_attr_i;
        end
        
        2'b01: begin  // Only free
          // Add tag back to free list
          free_list[free_tail] <= free_tag_i;
          free_tail <= (free_tail == DEPTH[TAG_W-1:0] - 1'b1) ? '0 : free_tail + 1'b1;
          free_count <= free_count + 1'b1;
          
          // Invalidate context table entry
          ctx_table[free_tag_i].valid <= 1'b0;
        end
        
        2'b11: begin  // Both allocation and free in same cycle
          // Update head for allocation
          free_head <= (free_head == DEPTH[TAG_W-1:0] - 1'b1) ? '0 : free_head + 1'b1;
          
          // Update tail for free
          free_list[free_tail] <= free_tag_i;
          free_tail <= (free_tail == DEPTH[TAG_W-1:0] - 1'b1) ? '0 : free_tail + 1'b1;
          
          // Count stays the same (alloc -1, free +1)
          
          // Update context table for allocation
          ctx_table[alloc_tag_o].valid        <= 1'b1;
          ctx_table[alloc_tag_o].requester_id <= alloc_req_id_i;
          ctx_table[alloc_tag_o].addr         <= alloc_addr_i;
          ctx_table[alloc_tag_o].length       <= alloc_len_i;
          ctx_table[alloc_tag_o].attr         <= alloc_attr_i;
          
          // Invalidate freed tag
          ctx_table[free_tag_i].valid <= 1'b0;
        end
        
        default: begin  // 2'b00 - No operation
          // Keep current state
        end
      endcase
    end
  end

  // Lookup logic - combinational read, always ready
  assign lookup_ready_o = 1'b1;  // Always ready to accept lookup requests
  
  // Combinational lookup outputs
  always_comb begin
    if(ctx_table[lookup_tag_i].valid) begin
      // Valid tag: return stored metadata
      cpl_req_id_o = ctx_table[lookup_tag_i].requester_id;
      cpl_addr_o   = ctx_table[lookup_tag_i].addr;
      cpl_len_o    = ctx_table[lookup_tag_i].length;
      cpl_attr_o   = ctx_table[lookup_tag_i].attr;
    end else begin
      // Invalid tag: return zeros (error case - unexpected completion)
      cpl_req_id_o = 16'b0;
      cpl_addr_o   = 32'b0;
      cpl_len_o    = 10'b0;
      cpl_attr_o   = 3'b0;
    end
  end


endmodule
