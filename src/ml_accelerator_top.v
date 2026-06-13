`timescale 1ns / 1ps

module ml_accelerator_top #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32, parameter integer C_S_AXI_ADDR_WIDTH = 6,
    parameter integer C_M_AXI_ADDR_WIDTH = 32, parameter integer C_M_AXI_DATA_WIDTH = 32
)
(
    input wire  clk, rst_n,

    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr, input wire s_axi_awvalid, output wire s_axi_awready,
    input wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_wdata, input wire [3:0] s_axi_wstrb, input wire s_axi_wvalid, output wire s_axi_wready,
    output wire [1:0] s_axi_bresp, output wire s_axi_bvalid, input wire s_axi_bready,
    input wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr, input wire s_axi_arvalid, output wire s_axi_arready,
    output wire [C_S_AXI_DATA_WIDTH-1:0] s_axi_rdata, output wire [1:0] s_axi_rresp, output wire s_axi_rvalid, input wire s_axi_rready,

    output wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr, output wire [7:0] m_axi_arlen, output wire [2:0] m_axi_arsize,
    output wire [1:0] m_axi_arburst, output wire m_axi_arvalid, input wire m_axi_arready,
    input wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata, input wire m_axi_rlast, input wire m_axi_rvalid, output wire m_axi_rready,

    output wire [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr, output wire [7:0] m_axi_awlen, output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst, output wire m_axi_awvalid, input wire m_axi_awready,
    output wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata, output wire [3:0] m_axi_wstrb, output wire m_axi_wlast,
    output wire m_axi_wvalid, input wire m_axi_wready,
    input wire [1:0] m_axi_bresp, input wire m_axi_bvalid, output wire m_axi_bready,

    output reg  irq_done
);
    wire [31:0] reg_ctrl, reg_m_size, reg_k_size, reg_n_size, reg_wgt_base, reg_inp_base, reg_out_base;
    reg  [31:0] reg_status;

    reg dma_rd_start, dma_wr_start;
    reg [31:0] dma_addr, dma_len;
    wire dma_rd_done, dma_wr_done, dma_stream_valid;
    wire [31:0] dma_stream_data;

    wire sys_start = reg_ctrl[0];
    reg sys_busy, sys_done;

    axi_lite_interface #(32, 6) u_cpu_if (
        .clk(clk), .rst_n(rst_n),
        .awaddr(s_axi_awaddr), .awvalid(s_axi_awvalid), .awready(s_axi_awready),
        .wdata(s_axi_wdata), .wvalid(s_axi_wvalid), .wready(s_axi_wready), .bresp(s_axi_bresp), .bvalid(s_axi_bvalid), .bready(s_axi_bready),
        .araddr(s_axi_araddr), .arvalid(s_axi_arvalid), .arready(s_axi_arready),
        .rdata(s_axi_rdata), .rresp(s_axi_rresp), .rvalid(s_axi_rvalid), .rready(s_axi_rready),
        .reg_ctrl(reg_ctrl), .reg_m_size(reg_m_size), .reg_k_size(reg_k_size), .reg_n_size(reg_n_size),
        .reg_wgt_base(reg_wgt_base), .reg_inp_base(reg_inp_base), .reg_out_base(reg_out_base), .reg_status(reg_status)
    );

    dma_controller #(32, 32) u_dma_read (
        .clk(clk), .rst_n(rst_n), .start(dma_rd_start), .base_addr(dma_addr), .transfer_length(dma_len),
        .done(dma_rd_done), .stream_data(dma_stream_data), .stream_valid(dma_stream_valid),
        .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready), .m_axi_rdata(m_axi_rdata), .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready)
    );

    reg [23:0] output_buffer [0:255]; 
    wire [8:0] out_buf_read_addr;
    wire [31:0] out_buf_read_data = {{8{output_buffer[out_buf_read_addr][23]}}, output_buffer[out_buf_read_addr]};

    dma_write_controller #(32, 32) u_dma_write (
        .clk(clk), .rst_n(rst_n), .start(dma_wr_start), .base_addr(reg_out_base), .transfer_length(32'd256),
        .done(dma_wr_done), .buf_read_addr(out_buf_read_addr), .buf_read_data(out_buf_read_data),
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready),
        .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb), .m_axi_wlast(m_axi_wlast), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready)
    );

    reg [7:0] weight_buffer [0:255]; 
    reg [7:0] input_buffer  [0:511]; 
    reg [8:0] wgt_idx, inp_idx;

    localparam S_IDLE=0, S_FETCH_WEIGHTS=1, S_LOAD_WEIGHTS=2, S_FETCH_INPUTS=3, S_COMPUTE=4, S_WRITE_BACK=5;
    reg [2:0] state;
    reg array_load_weight, array_en;
    reg [4:0] load_counter;
    reg [6:0] compute_counter;

    wire [383:0] flat_psum_out;
    wire signed [31:0] current_cc = $signed({1'b0, compute_counter});

    wire signed [31:0] out_row_w [0:15];
    genvar c_idx;
    generate
        for (c_idx = 0; c_idx < 16; c_idx = c_idx + 1) begin : gen_out_row
            assign out_row_w[c_idx] = current_cc - $signed(c_idx) - 16;
        end
    endgenerate
    
    integer col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            sys_busy <= 0; sys_done <= 0; irq_done <= 0;
            dma_rd_start <= 0; dma_wr_start <= 0; array_load_weight <= 0;
            array_en <= 0;
            wgt_idx <= 0; inp_idx <= 0; load_counter <= 0; compute_counter <= 0;
        end else begin
            reg_status <= {30'd0, sys_done, sys_busy};

            case (state)
                S_IDLE: begin
                    irq_done <= 0;
                    if (sys_start) begin
                        sys_done <= 0;
                        sys_busy <= 1;
                        wgt_idx <= 0; inp_idx <= 0;
                        state <= S_FETCH_WEIGHTS;
                        dma_addr <= reg_wgt_base; dma_len <= 64; dma_rd_start <= 1; 
                    end
                end
                
                S_FETCH_WEIGHTS: begin
                    dma_rd_start <= 0;
                    if (dma_stream_valid) begin
                        weight_buffer[wgt_idx]   <= dma_stream_data[7:0];
                        weight_buffer[wgt_idx+1] <= dma_stream_data[15:8]; 
                        weight_buffer[wgt_idx+2] <= dma_stream_data[23:16]; 
                        weight_buffer[wgt_idx+3] <= dma_stream_data[31:24]; 
                        wgt_idx <= wgt_idx + 4;
                    end
                    if (dma_rd_done) begin 
                        state <= S_LOAD_WEIGHTS;
                        load_counter <= 0; 
                        // FIX: Pre-assert controls to fix the 1-cycle delay row drop
                        array_load_weight <= 1; 
                        array_en <= 1;
                    end
                end
                
                S_LOAD_WEIGHTS: begin
                    if (load_counter == 15) begin
                        state <= S_FETCH_INPUTS;
                        array_en <= 0; array_load_weight <= 0; 
                        dma_addr <= reg_inp_base; dma_len <= 64; dma_rd_start <= 1;
                    end else begin
                        load_counter <= load_counter + 1;
                    end
                end
                
                S_FETCH_INPUTS: begin
                    dma_rd_start <= 0;
                    if (dma_stream_valid) begin
                        input_buffer[inp_idx]   <= dma_stream_data[7:0];
                        input_buffer[inp_idx+1] <= dma_stream_data[15:8]; 
                        input_buffer[inp_idx+2] <= dma_stream_data[23:16]; 
                        input_buffer[inp_idx+3] <= dma_stream_data[31:24]; 
                        inp_idx <= inp_idx + 4;
                    end
                    if (dma_rd_done) begin 
                        state <= S_COMPUTE;
                        compute_counter <= 0; 
                        array_en <= 1;
                    end
                end
                
                S_COMPUTE: begin
                    for (col = 0; col < 16; col = col + 1) begin
                        if (out_row_w[col] >= 0 && out_row_w[col] < 16) begin
                            output_buffer[out_row_w[col]*16 + col] <= flat_psum_out[col*24 +: 24];
                        end
                    end

                    if (compute_counter == 60) begin 
                        state <= S_WRITE_BACK;
                        array_en <= 0; dma_wr_start <= 1; 
                    end else begin
                        compute_counter <= compute_counter + 1;
                    end
                end
                
                S_WRITE_BACK: begin
                    dma_wr_start <= 0;
                    if (dma_wr_done) begin 
                        sys_busy <= 0; sys_done <= 1; irq_done <= 1; state <= S_IDLE;
                    end
                end
            endcase
        end
    end

    reg [127:0] flat_ifmap, flat_weight;
    integer k;
    reg signed [31:0] in_col;
    
    always @(*) begin
        // Default to zeros
        flat_weight = 128'd0;
        flat_ifmap  = 128'd0;

        if (state == S_COMPUTE) begin
            for (k = 0; k < 16; k = k + 1) begin
                in_col = current_cc - $signed(k);
                if (in_col >= 0 && in_col < 16)
                    flat_ifmap[k*8 +: 8] = input_buffer[in_col*16 + k];
            end
        end else if (state == S_LOAD_WEIGHTS) begin
            for (k = 0; k < 16; k = k + 1) begin
                flat_weight[k*8 +: 8] = weight_buffer[(15 - load_counter)*16 + k];
            end
        end
    end

    systolic_array_16x16 u_core (
        .clk(clk), .rst_n(rst_n), .en(array_en), .load_weight(array_load_weight),
        .flat_ifmap_in(flat_ifmap), .flat_weight_in(flat_weight),
        .flat_psum_in({384{1'b0}}), .flat_psum_out(flat_psum_out) 
    );
endmodule