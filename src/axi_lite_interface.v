module axi_lite_interface #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 6
)
(
    input wire  clk, rst_n,

    // AXI Slave Ports
    input wire [C_S_AXI_ADDR_WIDTH-1:0] awaddr, input wire awvalid, output reg awready,
    input wire [C_S_AXI_DATA_WIDTH-1:0] wdata, input wire wvalid, output reg wready,
    output reg [1:0] bresp, output reg bvalid, input wire bready,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] araddr, input wire arvalid, output reg arready,
    output reg [C_S_AXI_DATA_WIDTH-1:0] rdata, output reg [1:0] rresp,
    output reg rvalid, input wire rready,

    // Internal Registers (Outputs to Core)
    output reg [31:0] reg_ctrl, reg_m_size, reg_k_size, reg_n_size,
    output reg [31:0] reg_wgt_base, reg_inp_base, reg_out_base, // Added reg_out_base!

    input wire [31:0] reg_status
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            awready <= 0; wready <= 0; bvalid <= 0;
            reg_ctrl <= 0; reg_m_size <= 16; reg_k_size <= 16; reg_n_size <= 16;
            reg_wgt_base <= 0; reg_inp_base <= 0; reg_out_base <= 0;
        end else begin
            if (~awready && awvalid && wvalid) begin
                awready <= 1; wready <= 1;
                case (awaddr[5:2])
                    4'h0: reg_ctrl     <= wdata;
                    4'h2: reg_m_size   <= wdata;
                    4'h3: reg_k_size   <= wdata;
                    4'h4: reg_n_size   <= wdata;
                    4'h5: reg_wgt_base <= wdata;
                    4'h6: reg_inp_base <= wdata;
                    4'h7: reg_out_base <= wdata; // Offset 0x1C
                endcase
            end else begin
                awready <= 0; wready <= 0;
                if (reg_ctrl[0]) reg_ctrl[0] <= 0;
            end
            if (awready && wready) bvalid <= 1;
            else if (bready && bvalid) bvalid <= 0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arready <= 0; rvalid <= 0; rdata <= 0;
        end else begin
            if (~arready && arvalid) begin
                arready <= 1; rvalid <= 1;
                case (araddr[5:2])
                    4'h0: rdata <= reg_ctrl;
                    4'h1: rdata <= reg_status;
                    4'h2: rdata <= reg_m_size;
                    4'h3: rdata <= reg_k_size;
                    4'h4: rdata <= reg_n_size;
                    4'h7: rdata <= reg_out_base;
                    default: rdata <= 0;
                endcase
            end else begin
                arready <= 0;
                if (rvalid && rready) rvalid <= 0;
            end
        end
    end
endmodule