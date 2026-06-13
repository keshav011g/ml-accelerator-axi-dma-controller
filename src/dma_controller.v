module dma_controller #
(
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_M_AXI_DATA_WIDTH = 32
)
(
    input wire  clk,
    input wire  rst_n,

    input wire  start,
    input wire [C_M_AXI_ADDR_WIDTH-1:0] base_addr,
    input wire [31:0] transfer_length, 
    output reg  done,
    
    output reg  [C_M_AXI_DATA_WIDTH-1:0] stream_data,
    output reg  stream_valid,

    output reg [C_M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen,   
    output wire [2:0] m_axi_arsize,  
    output wire [1:0] m_axi_arburst, 
    output reg  m_axi_arvalid,
    input  wire m_axi_arready,
    input  wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_rdata,
    input  wire m_axi_rlast,
    input  wire m_axi_rvalid,
    output reg  m_axi_rready
);
    // FIX: Dynamically link AXI burst length to requested transfer length
    assign m_axi_arlen   = transfer_length[7:0] - 8'd1;
    assign m_axi_arsize  = 3'b010; // 4 bytes (32-bit)
    assign m_axi_arburst = 2'b01;  // INCR type

    reg [31:0] words_transferred;
    localparam S_IDLE = 0, S_ADDR = 1, S_READ = 2, S_DONE = 3;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            m_axi_arvalid <= 0;
            m_axi_rready <= 0;
            done <= 0;
            words_transferred <= 0;
            stream_valid <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    stream_valid <= 0;
                    done <= 0;
                    if (start) begin
                        m_axi_araddr <= base_addr;
                        words_transferred <= 0;
                        state <= S_ADDR;
                    end
                end

                S_ADDR: begin
                    stream_valid <= 0;
                    m_axi_arvalid <= 1;
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 0;
                        m_axi_rready <= 1; 
                        state <= S_READ;
                    end
                end

                S_READ: begin
                    stream_valid <= 0;
                    if (m_axi_rvalid && m_axi_rready) begin
                        stream_data <= m_axi_rdata;
                        stream_valid <= 1;
                        words_transferred <= words_transferred + 1;

                        if (words_transferred == (transfer_length - 1)) begin
                            m_axi_rready <= 0;
                            state <= S_DONE;
                        end else if (m_axi_rlast) begin
                            m_axi_araddr <= m_axi_araddr + 1024;
                            state <= S_ADDR;
                        end
                    end
                end

                S_DONE: begin
                    stream_valid <= 0;
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule