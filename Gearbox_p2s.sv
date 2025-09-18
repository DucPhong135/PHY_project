module gearbox_p2s #(
    parameter IN_W  = 130,
    parameter OUT_W = 10
)(
    input  logic             clk, rst_n,
    input  logic [IN_W-1:0]  din,
    input  logic            din_valid,
    output logic            din_ready,
    output logic [OUT_W-1:0] ser_word,
    output logic            ser_valid,
    output logic            busy
);


    localparam N = IN_W / OUT_W; // number of output words per input word
    localparam CNT_W = $clog2(N);

    typedef enum logic [1:0] {
        IDLE,
        LOAD,
        SHIFT
    } state_t;

    state_t state, next_state;
    logic [IN_W-1:0] shift_reg;
    logic [CNT_W-1:0] cnt, next_cnt;
    logic load_en, shift_en;

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
        load_en = 1'b0;
        shift_en = 1'b0;
        din_ready = 1'b0;

        case (state)
            IDLE: begin
                if (din_valid) begin
                    next_state = LOAD;
                    din_ready = 1'b1;
                end
            end
            LOAD: begin
                next_state = SHIFT;
                load_en = 1'b1;
            end
            SHIFT: begin
                if (cnt == N - 1) begin
                    next_state = IDLE;
                end else begin
                    shift_en = 1'b1;
                end
            end
        endcase
    end

    // Shift register and counter logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 1'b0;
            cnt <= 1'b0;
        end else begin
            if (load_en) begin
                shift_reg <= din;
                cnt <= 1'b0;
            end else if (shift_en) begin
                shift_reg <= {shift_reg[IN_W-OUT_W-1:0], {OUT_W{1'b0}}};
                cnt <= cnt + 1;
            end
        end
    end

    // Output logic
    assign ser_word = shift_reg[OUT_W-1:0];
    assign ser_valid = (state == SHIFT);
    assign busy = (state != IDLE);

endmodule