// Gearbox: Serial-to-Parallel (10-bit chunks -> 130-bit word)
module gearbox_s2p #(
    parameter OUT_W = 130,
    parameter CHUNK_W = 10
)(
    input  logic                  clk,       // clock for chunk input
    input  logic                  rst_n,     // active-low reset

    input  logic [CHUNK_W-1:0]    chunk_in,  // incoming 10-bit parallel word
    input  logic                  chunk_valid, // chunk valid

    output logic [OUT_W-1:0]      par_out,   // reassembled 130-bit word
    output logic                  par_valid  // high when par_out is valid
);


    localparam N = OUT_W / CHUNK_W; // number of chunks per output word
    localparam CNT_W = $clog2(N);

    typedef enum logic [1:0] {
        IDLE,
        ASSEMBLE
    } state_t;

    state_t state, next_state;
    logic [OUT_W-1:0] shift_reg;
    logic [CNT_W-1:0] cnt, next_cnt;
    logic assemble_en;

    // State transition
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Next state logic
    always_comb begin
        next_state = state;
        assemble_en = 1'b0;
        par_valid = 1'b0;

        case (state)
            IDLE: begin
                if (chunk_valid) begin
                    next_state = ASSEMBLE;
                    assemble_en = 1'b1;
                end
            end
            ASSEMBLE: begin
                if (cnt == N - 1) begin
                    next_state = IDLE;
                    par_valid = 1'b1;
                end else if (chunk_valid) begin
                    assemble_en = 1'b1;
                end
            end
        endcase
    end

    // Counter for number of chunks received
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            cnt <= '0;
        else if(state == IDLE)
            cnt <= '0;
        else if (assemble_en)
            cnt <= next_cnt;
    end

    always_comb begin
        if (assemble_en)
            next_cnt = cnt + 1'b1;
        else
            next_cnt = cnt;
    end

    // Shift register to assemble the output word
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg <= 1'b0;
        else if(state == IDLE)
            shift_reg <= {OUT_W{1'b0}};
        else if (assemble_en)
            shift_reg <= {shift_reg[OUT_W-CHUNK_W-1:0], chunk_in};
    end

endmodule
