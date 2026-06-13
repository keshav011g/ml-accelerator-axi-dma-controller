`timescale 1ns / 1ps

module tb_processing_element;

    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg load_weight;
    reg signed [7:0] ifmap_in;
    reg signed [23:0] psum_in;
    reg signed [7:0] weight_in;

    // Outputs
    wire signed [7:0] ifmap_out;
    wire signed [23:0] psum_out;
    wire signed [7:0] weight_out;

    // Instantiate the Unit Under Test (UUT)
    processing_element uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .load_weight(load_weight),
        .ifmap_in(ifmap_in),
        .psum_in(psum_in),
        .weight_in(weight_in),
        .ifmap_out(ifmap_out),
        .psum_out(psum_out),
        .weight_out(weight_out)
    );

    // Clock Generation (100 MHz)
    always #5 clk = ~clk;

    initial begin
        // Setup GTKWave Output
        $dumpfile("tb_pe.vcd");
        $dumpvars(0, tb_processing_element);

        // 1. Initialize Inputs
        clk = 0;
        rst_n = 0;
        en = 0;
        load_weight = 0;
        ifmap_in = 0;
        psum_in = 0;
        weight_in = 0;

        // Release Reset
        #15 rst_n = 1;
        en = 1;

        $display("--- Starting Processing Element Test ---");

        // ---------------------------------------------------------
        // TEST 1: Load the Weight
        // ---------------------------------------------------------
        @(posedge clk);
        load_weight = 1;
        weight_in = 8'd15;   // Let's load a weight of 15
        
        @(posedge clk);
        load_weight = 0;     // Lock the weight in the PE
        
        // ---------------------------------------------------------
        // TEST 2: Perform MAC (Positive numbers)
        // Equation: psum_out = psum_in + (ifmap_in * weight)
        // ---------------------------------------------------------
        ifmap_in = 8'd10;    // Input = 10
        psum_in  = 24'd0;    // Initial PSum = 0
        
        @(posedge clk);      // Wait for combinational logic + register
        #1;                  // Small delay to read output clearly
        $display("TEST 2 [10 * 15 + 0]   -> Output: %d | Expected: 150", psum_out);

        // ---------------------------------------------------------
        // TEST 3: Perform MAC (Negative input, Accumulate)
        // Equation: psum_out = 150 + (-5 * 15) = 75
        // ---------------------------------------------------------
        @(posedge clk);
        ifmap_in = -8'd5;    // Input = -5
        psum_in  = 24'd150;  // Incoming PSum from a PE above us
        
        @(posedge clk);
        #1;
        $display("TEST 3 [-5 * 15 + 150] -> Output: %d  | Expected: 75", psum_out);

        // ---------------------------------------------------------
        // TEST 4: Boundary Testing (Max Negative values)
        // Equation: psum_out = 0 + (-128 * -128) = 16384
        // ---------------------------------------------------------
        // Load new weight
        @(posedge clk);
        load_weight = 1;
        weight_in = -8'd128;
        
        @(posedge clk);
        load_weight = 0;
        ifmap_in = -8'd128;
        psum_in = 24'd0;

        @(posedge clk);
        #1;
        $display("TEST 4 [-128 * -128 + 0] -> Output: %d | Expected: 16384", psum_out);

        #20 $display("--- PE Test Complete ---");
        $finish;
    end
endmodule