module pcie_descrambler_128b #(
    parameter int DW = 128,    // keep DW = 128 for Gen3+ PCIe
    parameter int LFSR_WIDTH = 23, // Width of the LFSR
    parameter int SCRAMBLE_WIDTH = 32
)(
    // Clocks / Reset
    input  logic              clk,
    input  logic              rst_n,

    // Unscrambled payload from MAC / DLL
    input  logic [DW-1:0]     in_data,
    input  logic              in_valid,      
    input  logic              in_is_ctl,     // 1 = CONTROL block  (bypass)

    // Scrambled payload toward encoder
    output logic [DW-1:0]     out_data,
    output logic              out_valid,      // 1-cycle strobe

    input logic             scrambler_enable
);


logic [DW-1:0] data_reg_0;
logic [DW-1:0] data_reg_1;
logic [DW-1:0] data_reg_2;
logic [DW-1:0] data_reg_3;
logic [DW-1:0] data_reg_4;


logic in_is_ctl_reg_0;
logic in_is_ctl_reg_1;
logic in_is_ctl_reg_2;
logic in_is_ctl_reg_3;
logic in_is_ctl_reg_4;


logic LFSR_enable_0;
logic LFSR_enable_1;
logic LFSR_enable_2;
logic LFSR_enable_3;


logic in_valid_reg_0;
logic in_valid_reg_1;
logic in_valid_reg_2;
logic in_valid_reg_3;
logic in_valid_reg_4;

logic[SCRAMBLE_WIDTH-1:0] LFSR_D_OUT_0;
logic[SCRAMBLE_WIDTH-1:0] LFSR_D_OUT_1;
logic[SCRAMBLE_WIDTH-1:0] LFSR_D_OUT_2;
logic[SCRAMBLE_WIDTH-1:0] LFSR_D_OUT_3;


always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_reg_0 <= '0;
        in_is_ctl_reg_0 <= 1'b1;

    end
    else begin
        if(in_valid) begin
            data_reg_0 <= in_data;
            in_is_ctl_reg_0 <= in_is_ctl;
            in_valid_reg_0 <= in_valid;
        end
        else begin
            data_reg_0 <= {DW{1'b0}};
            in_is_ctl_reg_0 <= 1'b1;
            in_valid_reg_0 <= 1'b0;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_reg_1 <= '0;
        in_is_ctl_reg_1 <= 1'b1;

    end
    else begin
        in_valid_reg_1 <= in_valid_reg_0;
        in_is_ctl_reg_1 <= in_is_ctl_reg_0;
        if(!in_is_ctl_reg_0) begin
            data_reg_1 <= {data_reg_0[DW-SCRAMBLE_WIDTH-1:0], LFSR_D_OUT_0};
        end
        else begin
            data_reg_1 <= data_reg_0;
        end
    end
end


always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_reg_2 <= '0;
        in_is_ctl_reg_2 <= 1'b1;

    end
    else begin
        in_valid_reg_2 <= in_valid_reg_1;
        in_is_ctl_reg_2 <= in_is_ctl_reg_1;
        if(!in_is_ctl_reg_1) begin
            data_reg_2 <= {data_reg_1[DW-SCRAMBLE_WIDTH-1:0], LFSR_D_OUT_1};
        end
        else begin
            data_reg_2 <= data_reg_1;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_reg_3 <= '0;
        in_is_ctl_reg_3 <= 1'b1;

    end
    else begin
        in_valid_reg_3 <= in_valid_reg_2;
        in_is_ctl_reg_3 <= in_is_ctl_reg_2;
        if(!in_is_ctl_reg_2) begin
            data_reg_3 <= {data_reg_2[DW-SCRAMBLE_WIDTH-1:0], LFSR_D_OUT_2};
        end
        else begin
            data_reg_3 <= data_reg_2;
        end
    end
end

always_ff @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        data_reg_4 <= '0;
        in_is_ctl_reg_4 <= 1'b1;
    end
    else begin
        in_valid_reg_4 <= in_valid_reg_3;
        in_is_ctl_reg_4 <= in_is_ctl_reg_3;
        if(!in_is_ctl_reg_3) begin
            data_reg_4 <= {data_reg_3[DW-SCRAMBLE_WIDTH-1:0], LFSR_D_OUT_3};
        end
        else begin
            data_reg_4 <= data_reg_3;
        end
    end
end


assign out_data = data_reg_4;
assign out_valid = in_valid_reg_4;


// Instantiate LFSR-based scrambler
assign LFSR_enable_0 =(!in_is_ctl_reg_0) && scrambler_enable; // only scramble data when valid and not control
Parallel_LFSR #(
    .scramble_WIDTH(SCRAMBLE_WIDTH),
    .LFSR_WIDTH(LFSR_WIDTH)
) u_lfsr_0 (
    .clk(clk),
    .reset_n(rst_n),
    .enable(LFSR_enable_0), // only scramble data when valid and not control
    .D_IN(data_reg_0[DW-1:DW-SCRAMBLE_WIDTH]),
    .D_OUT(LFSR_D_OUT_0)
);

assign LFSR_enable_1 =(!in_is_ctl_reg_1) && scrambler_enable; // only scramble data when valid and not control
Parallel_LFSR #(
    .scramble_WIDTH(SCRAMBLE_WIDTH),
    .LFSR_WIDTH(LFSR_WIDTH)
) u_lfsr_1 (
    .clk(clk),
    .reset_n(rst_n),
    .enable(LFSR_enable_1), // only scramble data when valid and not control
    .D_IN(data_reg_1[DW-1:DW-SCRAMBLE_WIDTH]),
    .D_OUT(LFSR_D_OUT_1)
);

assign LFSR_enable_2 =(!in_is_ctl_reg_2) && scrambler_enable; // only scramble data when valid and not control
Parallel_LFSR #(
    .scramble_WIDTH(SCRAMBLE_WIDTH),
    .LFSR_WIDTH(LFSR_WIDTH)
) u_lfsr_2 (
    .clk(clk),
    .reset_n(rst_n),
    .enable(LFSR_enable_2), // only scramble data when valid and not control
    .D_IN(data_reg_2[DW-1:DW-SCRAMBLE_WIDTH]),
    .D_OUT(LFSR_D_OUT_2)
);


assign LFSR_enable_3 =(!in_is_ctl_reg_3) && scrambler_enable; // only scramble data when valid and not control
Parallel_LFSR #(
    .scramble_WIDTH(SCRAMBLE_WIDTH),
    .LFSR_WIDTH(LFSR_WIDTH)
) u_lfsr_3 (
    .clk(clk),
    .reset_n(rst_n),
    .enable(LFSR_enable_3), // only scramble data when valid and not control
    .D_IN(data_reg_3[DW-1:DW-SCRAMBLE_WIDTH]),
    .D_OUT(LFSR_D_OUT_3)
);


endmodule