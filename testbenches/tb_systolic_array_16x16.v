`timescale 1ns / 1ps

module tb_systolic_array_16x16;

    reg clk, rst_n, en, load_weight;
    reg  [127:0] flat_ifmap_in, flat_weight_in;
    reg  [383:0] flat_psum_in;
    wire [383:0] flat_psum_out;

    // Instantiate the Array
    systolic_array_16x16 uut (
        .clk(clk), .rst_n(rst_n), .en(en), .load_weight(load_weight),
        .flat_ifmap_in(flat_ifmap_in), .flat_weight_in(flat_weight_in),
        .flat_psum_in(flat_psum_in), .flat_psum_out(flat_psum_out)
    );

    always #5 clk = ~clk; // 100 MHz clock

    integer i;
    // Extract column 0 (Left-most) and column 15 (Right-most) outputs for viewing
    wire signed [23:0] col_0_out  = flat_psum_out[23:0];
    wire signed [23:0] col_15_out = flat_psum_out[383:360];

    initial begin
        $dumpfile("tb_array.vcd"); $dumpvars(0, tb_systolic_array_16x16);
        clk = 0; rst_n = 0; en = 0; load_weight = 0;
        flat_ifmap_in = 0; flat_weight_in = 0; flat_psum_in = 0;

        #15 rst_n = 1; en = 1;

        $display("--- Phase 1: Loading Weights (All PEs get '2') ---");
        load_weight = 1;
        for (i = 0; i < 16; i = i + 1) begin
            flat_weight_in = {16{8'd2}}; 
            @(posedge clk);
        end
        
        $display("--- Phase 2: Compute (Feeding '10' into all rows) ---");
        load_weight = 0; flat_weight_in = 0;
        for (i = 0; i < 16; i = i + 1) begin
            flat_ifmap_in = {16{8'd10}}; 
            @(posedge clk);
        end

        $display("--- Phase 3: Flushing Array (Feeding '0's to push remaining data out) ---");
        for (i = 0; i < 32; i = i + 1) begin
            flat_ifmap_in = 0;
            @(posedge clk);
        end
        $display("--- Test Complete ---");
        $finish;
    end

    // Monitor the outputs dynamically
    always @(posedge clk) begin
        if (col_0_out > 0 || col_15_out > 0) begin
            $display("Time: %0t ns | Col 0 Out: %d | Col 15 Out: %d", $time, col_0_out, col_15_out);
        end
    end
endmodule