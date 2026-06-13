`timescale 1ns / 1ps

module processing_element (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    input  wire load_weight,

    // Daisy-chain connections from adjacent PEs
    input  wire signed [7:0]  ifmap_in,
    input  wire signed [23:0] psum_in,
    input  wire signed [7:0]  weight_in,

    // Daisy-chain connections to adjacent PEs
    output reg  signed [7:0]  ifmap_out,
    output reg  signed [23:0] psum_out,
    output reg  signed [7:0]  weight_out
);

    // Internal Register for Weight-Stationary Dataflow
    reg signed [7:0] internal_weight;

    // Behavioral Multiplier
    // The synthesis tool will map this to a DSP block or optimized fabric logic
    wire signed [15:0] product;
    assign product = ifmap_in * internal_weight;

    // -------------------------------------------------------------------------
    // SEQUENTIAL LOGIC & DAISY CHAINING
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            internal_weight <= 8'd0;
            weight_out      <= 8'd0;
            ifmap_out       <= 8'd0;
            psum_out        <= 24'd0;
        end else if (en) begin
            // Feature maps always flow horizontally
            ifmap_out <= ifmap_in;
            
            if (load_weight) begin
                // Phase 1: Load Weights vertically down the columns
                internal_weight <= weight_in;
                weight_out      <= weight_in;
                psum_out        <= psum_in; // Pass zeros
            end else begin
                // Phase 2: Compute MAC and pass partial sums vertically
                // We sign-extend the 16-bit product to 24-bits before adding
                psum_out <= psum_in + {{8{product[15]}}, product};
            end
        end
    end

endmodule