`timescale 1ns / 1ps

module tb_scrambler_descrambler;

    // Parameters
    parameter int DW = 128;
    parameter int LFSR_WIDTH = 23;
    parameter int SCRAMBLE_WIDTH = 32;
    parameter int CLK_PERIOD = 10; // 100MHz clock
    
    // Clock and Reset
    logic clk;
    logic rst_n;
    
    // Scrambler signals
    logic [DW-1:0]     scr_in_data;
    logic              scr_in_valid;
    logic              scr_in_is_ctl;
    logic [DW-1:0]     scr_out_data;
    logic              scr_out_valid;
    
    // Descrambler signals  
    logic [DW-1:0]     dscr_in_data;
    logic              dscr_in_valid;
    logic              dscr_in_is_ctl;
    logic [DW-1:0]     dscr_out_data;
    logic              dscr_out_valid;
    
    // Test vectors and control
    logic [DW-1:0] test_data_queue[$];
    logic [DW-1:0] original_data;
    logic [DW-1:0] scrambled_data;
    logic [DW-1:0] descrambled_data;
    
    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // DUT Instantiation - Scrambler
    pcie_scrambler_128b #(
        .DW(DW),
        .LFSR_WIDTH(LFSR_WIDTH),
        .SCRAMBLE_WIDTH(SCRAMBLE_WIDTH)
    ) u_scrambler (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(scr_in_data),
        .in_valid(scr_in_valid),
        .in_is_ctl(scr_in_is_ctl),
        .out_data(scr_out_data),
        .out_valid(scr_out_valid)
    );
    
    // DUT Instantiation - Descrambler
    pcie_descrambler_128b #(
        .DW(DW),
        .LFSR_WIDTH(LFSR_WIDTH),
        .SCRAMBLE_WIDTH(SCRAMBLE_WIDTH)
    ) u_descrambler (
        .clk(clk),
        .rst_n(rst_n),
        .in_data(dscr_in_data),
        .in_valid(dscr_in_valid),
        .in_is_ctl(dscr_in_is_ctl),
        .out_data(dscr_out_data),
        .out_valid(dscr_out_valid)
    );
    
    // Connect scrambler output to descrambler input
    always_ff @(posedge clk) begin
        if (scr_out_valid) begin
            dscr_in_data <= scr_out_data;
            dscr_in_valid <= 1'b1;
            dscr_in_is_ctl <= scr_in_is_ctl; // Pass through control flag
        end else begin
            dscr_in_valid <= 1'b0;
        end
    end
    
    // Test stimulus and monitoring
    initial begin
        // Initialize signals
        rst_n = 0;
        scr_in_data = 0;
        scr_in_valid = 0;
        scr_in_is_ctl = 0;
        
        // Reset sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(10) @(posedge clk);
        
        $display("=== Starting Scrambler/Descrambler Test ===");
        $display("Time: %0t", $time);
        
        // Test 1: Basic functionality test
        test_basic_functionality();
        
        // Test 2: Control block bypass test
        test_control_bypass();
        
        // Test 3: Random data test
        test_random_data();
        
        // Test 4: Pattern data test
        test_pattern_data();
        
        // Test 5: Back-to-back transactions
        test_back_to_back();
        
        // Test 6: Timing test - 8 packets, 1 per clock cycle
        test_timing_8_packets();
        
        // Final results
        $display("\n=== Test Results ===");
        $display("Total Tests: %0d", test_count);
        $display("Passed: %0d", pass_count);
        $display("Failed: %0d", fail_count);
        
        if (fail_count == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", fail_count);
        end
        
        $finish;
    end
    
    // Task: Basic functionality test
    task test_basic_functionality();
        $display("\n--- Test 1: Basic Functionality ---");
        
        // Test with simple data patterns
        send_data(128'h0123456789ABCDEF_FEDCBA9876543210, 1'b0);
        send_data(128'hFFFFFFFF_FFFFFFFF_FFFFFFFF_FFFFFFFF, 1'b0);
        send_data(128'h00000000_00000000_00000000_00000000, 1'b0);
        send_data(128'hAAAAAAAA_AAAAAAAA_AAAAAAAA_AAAAAAAA, 1'b0);
        
        wait_for_completion();
    endtask
    
    // Task: Control block bypass test
    task test_control_bypass();
        $display("\n--- Test 2: Control Block Bypass ---");
        
        // Control blocks should pass through unchanged
        send_data(128'h1234567890ABCDEF_1234567890ABCDEF, 1'b1);
        send_data(128'hDEADBEEFCAFEBABE_DEADBEEFCAFEBABE, 1'b1);
        
        wait_for_completion();
    endtask
    
    // Task: Random data test  
    task test_random_data();
        $display("\n--- Test 3: Random Data Test ---");
        
        for (int i = 0; i < 20; i++) begin
            logic [DW-1:0] random_data;
            random_data = {$random(), $random(), $random(), $random()};
            send_data(random_data, 1'b0);
        end
        
        wait_for_completion();
    endtask
    
    // Task: Pattern data test
    logic [DW-1:0] pattern;
    task test_pattern_data();
        $display("\n--- Test 4: Pattern Data Test ---");
        
        // Walking ones
        for (int i = 0; i < DW; i++) begin
            pattern = 1'b1 << i;
            send_data(pattern, 1'b0);
        end
        
        // Walking zeros
        for (int i = 0; i < DW; i++) begin
            pattern = ~(1'b1 << i);
            send_data(pattern, 1'b0);
        end
        
        wait_for_completion();
    endtask
    
    // Task: Back-to-back transactions
    logic [DW-1:0] data;
    task test_back_to_back();
        $display("\n--- Test 5: Back-to-Back Transactions ---");
        
        // Send multiple data words in consecutive cycles
        for (int i = 0; i < 10; i++) begin
            data = i * 32'h01010101;
            @(posedge clk);
            scr_in_data <= data;
            scr_in_valid <= 1'b1;
            scr_in_is_ctl <= 1'b0;
            test_data_queue.push_back(data);
        end
        
        @(posedge clk);
        scr_in_valid <= 1'b0;
        
        wait_for_completion();
    endtask
    
    // Task: Timing test - 8 packets, 1 per clock cycle
    logic [DW-1:0] timing_data[8];
    time start_time, end_time;
    
    task test_timing_8_packets();
        $display("\n--- Test 6: Timing Test - 8 Packets (1 per clock) ---");
        
        // Prepare test data packets
        timing_data[0] = 128'hDEADBEEF_CAFEBABE_12345678_9ABCDEF0;
        timing_data[1] = 128'h11111111_22222222_33333333_44444444;
        timing_data[2] = 128'h55555555_66666666_77777777_88888888;
        timing_data[3] = 128'h99999999_AAAAAAAA_BBBBBBBB_CCCCCCCC;
        timing_data[4] = 128'hDDDDDDDD_EEEEEEEE_FFFFFFFF_00000000;
        timing_data[5] = 128'hFEDCBA98_76543210_01234567_89ABCDEF;
        timing_data[6] = 128'hA5A5A5A5_5A5A5A5A_C3C3C3C3_3C3C3C3C;
        timing_data[7] = 128'h0F0F0F0F_F0F0F0F0_33333333_CCCCCCCC;
        
        $display("Starting timing test at time: %0t", $time);
        start_time = $time;
        
        // Send 8 packets back-to-back (1 per clock cycle)
        for (int i = 0; i < 8; i++) begin
            @(posedge clk);
            scr_in_data <= timing_data[i];
            scr_in_valid <= 1'b1;
            scr_in_is_ctl <= 1'b0;
            test_data_queue.push_back(timing_data[i]);
            $display("Cycle %0d: Sending packet %0d: %h", i+1, i, timing_data[i]);
        end
        
        @(posedge clk);
        scr_in_valid <= 1'b0;
        end_time = $time;
        
        $display("Packet transmission completed at time: %0t", $time);
        $display("Total transmission time: %0t (8 packets in %0d clock cycles)", 
                 end_time - start_time, (end_time - start_time) / CLK_PERIOD);
        
        // Wait for all data to flow through the pipeline
        wait_for_completion();
        
        $display("Timing test completed successfully");
    endtask
    
    // Task: Send data to scrambler
    task send_data(logic [DW-1:0] data, logic is_ctl);
        @(posedge clk);
        scr_in_data <= data;
        scr_in_valid <= 1'b1;
        scr_in_is_ctl <= is_ctl;
        test_data_queue.push_back(data);
        
        @(posedge clk);
        scr_in_valid <= 1'b0;
    endtask
    
    // Task: Wait for all data to be processed
    task wait_for_completion();
        // Wait for pipeline to complete
        repeat(20) @(posedge clk);
        
        // Check if all data has been processed
        while (test_data_queue.size() > 0) begin
            @(posedge clk);
        end
        
        repeat(10) @(posedge clk);
    endtask
    
    // Monitor and check descrambler output
    always_ff @(posedge clk) begin
        if (dscr_out_valid && test_data_queue.size() > 0) begin
            original_data = test_data_queue.pop_front();
            descrambled_data = dscr_out_data;
            
            test_count++;
            
            if (scr_in_is_ctl) begin
                // Control blocks should pass through unchanged
                if (descrambled_data === original_data) begin
                    $display("PASS: Control block bypass - Original: %h, Descrambled: %h", 
                            original_data, descrambled_data);
                    pass_count++;
                end else begin
                    $display("FAIL: Control block bypass - Original: %h, Descrambled: %h", 
                            original_data, descrambled_data);
                    fail_count++;
                end
            end else begin
                // Data blocks should be scrambled then descrambled back to original
                if (descrambled_data === original_data) begin
                    $display("PASS: Data block - Original: %h, Descrambled: %h", 
                            original_data, descrambled_data);
                    pass_count++;
                end else begin
                    $display("FAIL: Data block - Original: %h, Descrambled: %h", 
                            original_data, descrambled_data);
                    fail_count++;
                end
            end
        end
    end
    
    // Monitor scrambler output for debugging
    always_ff @(posedge clk) begin
        if (scr_out_valid) begin
            $display("DEBUG: Scrambled data: %h (Control: %b)", scr_out_data, scr_in_is_ctl);
        end
    end
    
    // Timeout watchdog
    initial begin
        #10000000; // 10ms timeout
        $display("ERROR: Test timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("scrambler_descrambler_tb.vcd");
        $dumpvars(0, tb_scrambler_descrambler);
    end

endmodule