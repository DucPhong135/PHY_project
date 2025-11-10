module tl_fifo 
import tl_pkg::*;
#( 
    parameter int DEPTH = 32
)(
    input logic         clk,
    input logic         rst_n,

    // Write interface
    input tl_pkg::tl_stream_t  wr_data_i,
    input logic                wr_valid_i,
    output logic               wr_ready_o,

    // Read interface
    output tl_pkg::tl_stream_t  rd_data_o,
    output logic                rd_valid_o,
    input logic                 rd_ready_i
);

// FIFO memory
tl_pkg::tl_stream_t [DEPTH-1:0] fifo_mem;

// Pointers: Extra bit for full/empty detection
logic [$clog2(DEPTH):0]  wr_ptr;
logic [$clog2(DEPTH):0]  rd_ptr;

// Address width (without extra MSB)
localparam int ADDR_W = $clog2(DEPTH);

// Write and read addresses (mask off MSB)
logic [ADDR_W-1:0] wr_addr = wr_ptr[ADDR_W-1:0];
logic [ADDR_W-1:0] rd_addr = rd_ptr[ADDR_W-1:0];

// Full and empty detection
logic full  = (wr_ptr[ADDR_W] != rd_ptr[ADDR_W]) && (wr_addr == rd_addr);
logic empty = (wr_ptr == rd_ptr);

// Write logic
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        wr_ptr <= '0;
    end
    else begin
        if(wr_valid_i && wr_ready_o) begin
            fifo_mem[wr_addr] <= wr_data_i;
            wr_ptr <= wr_ptr + 1'b1;
        end
    end
end

// Read pointer logic
always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_ptr <= '0;
    end
    else begin
        if(rd_valid_o && rd_ready_i) begin
            rd_ptr <= rd_ptr + 1'b1;
        end
    end
end

// Combinational read data output
assign rd_data_o = fifo_mem[rd_addr];

// Control signals
assign wr_ready_o = !full;
assign rd_valid_o = !empty && rd_ready_i;

endmodule : tl_fifo


