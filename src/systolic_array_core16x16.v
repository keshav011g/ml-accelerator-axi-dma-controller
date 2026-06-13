`timescale 1ns / 1ps

module systolic_array_16x16 (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         en,
    input  wire         load_weight,

    // Flat buses from Top Module (DMA/SRAM)
    input  wire [127:0] flat_ifmap_in,   // 16 rows * 8 bits
    input  wire [127:0] flat_weight_in,  // 16 cols * 8 bits
    input  wire [383:0] flat_psum_in,    // 16 cols * 24 bits
    
    output wire [383:0] flat_psum_out    // 16 cols * 24 bits
);

    // ----------------------------------------------------------------------
    // Internal 2D Wiring Grid
    // ----------------------------------------------------------------------
    wire signed [7:0]  ifmap_wires  [0:15][0:16];  // [row][col]
    wire signed [23:0] psum_wires   [0:16][0:15];  // [row][col]
    wire signed [7:0]  weight_wires [0:16][0:15];  // [row][col]

    // ----------------------------------------------------------------------
    // Unpack Flat Inputs & Assign Boundaries
    // ----------------------------------------------------------------------
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : boundaries
            // Left Edge: Inputs enter column 0
            assign ifmap_wires[i][0] = flat_ifmap_in[i*8 + 7 : i*8];
            
            // Top Edge: Weights and initial Partial Sums enter row 0
            assign weight_wires[0][i] = flat_weight_in[i*8 + 7 : i*8];
            assign psum_wires[0][i]   = flat_psum_in[i*24 + 23 : i*24];
            
            // Bottom Edge: Results exit row 16
            assign flat_psum_out[i*24 + 23 : i*24] = psum_wires[16][i];
        end
    endgenerate

    // ----------------------------------------------------------------------
    // Generate the 16x16 PE Grid (256 MAC Units)
    // ----------------------------------------------------------------------
    genvar r, c;
    generate
        for (r = 0; r < 16; r = r + 1) begin : ROW
            for (c = 0; c < 16; c = c + 1) begin : COL
                
                processing_element pe (
                    .clk         (clk),
                    .rst_n       (rst_n),
                    .en          (en),
                    .load_weight (load_weight),
                    
                    // Inputs (From Left, Top, Top)
                    .ifmap_in    (ifmap_wires[r][c]),
                    .psum_in     (psum_wires[r][c]),
                    .weight_in   (weight_wires[r][c]),
                    
                    // Outputs (To Right, Bottom, Bottom)
                    .ifmap_out   (ifmap_wires[r][c+1]),
                    .psum_out    (psum_wires[r+1][c]),
                    .weight_out  (weight_wires[r+1][c])
                );
                
            end
        end
    endgenerate

endmodule