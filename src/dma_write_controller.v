module dma_write_controller #
(
    parameter integer C_M_AXI_ADDR_WIDTH = 32,
    parameter integer C_M_AXI_DATA_WIDTH = 32
)
(
    input wire  clk, rst_n, start,
    input wire [C_M_AXI_ADDR_WIDTH-1:0] base_addr,
    input wire [31:0] transfer_length,
    output reg  done,
    
    output reg [8:0] buf_read_addr,
    input wire [31:0] buf_read_data,

    output reg [C_M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    output wire [7:0] m_axi_awlen, output wire [2:0] m_axi_awsize,
    output wire [1:0] m_axi_awburst, output reg m_axi_awvalid, input wire m_axi_awready,
    output wire [C_M_AXI_DATA_WIDTH-1:0] m_axi_wdata, output wire [3:0] m_axi_wstrb,
    output reg m_axi_wlast, output reg m_axi_wvalid, input wire m_axi_wready,
    input wire [1:0] m_axi_bresp, input wire m_axi_bvalid, output reg m_axi_bready
);

    assign m_axi_awlen   = transfer_length - 1; 
    assign m_axi_awsize  = 3'b010; // 4 bytes
    assign m_axi_awburst = 2'b01;  // INCR
    assign m_axi_wdata   = buf_read_data; // DIRECT MAPPING (Fixes the shift bug)
    assign m_axi_wstrb   = 4'hF;

    reg [31:0] words_transferred;
    localparam S_IDLE=0, S_ADDR=1, S_WRITE=2, S_RESP=3;
    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE; m_axi_awvalid <= 0; m_axi_wvalid <= 0; m_axi_wlast <= 0;
            m_axi_bready <= 0; done <= 0; words_transferred <= 0; buf_read_addr <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        m_axi_awaddr <= base_addr;
                        words_transferred <= 0;
                        buf_read_addr <= 0;
                        state <= S_ADDR;
                    end
                end
                S_ADDR: begin
                    m_axi_awvalid <= 1;
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 0;
                        m_axi_wvalid <= 1;
                        m_axi_wlast <= (transfer_length == 1);
                        state <= S_WRITE;
                    end
                end
                S_WRITE: begin
                    if (m_axi_wvalid && m_axi_wready) begin
                        words_transferred <= words_transferred + 1;
                        buf_read_addr <= buf_read_addr + 1;
                        
                        if (words_transferred == transfer_length - 1) begin
                            m_axi_wvalid <= 0; 
                            m_axi_wlast <= 0; 
                            m_axi_bready <= 1;
                            state <= S_RESP;
                        end else if (words_transferred == transfer_length - 2) begin
                            m_axi_wlast <= 1;
                        end
                    end
                end
                S_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 0; done <= 1; state <= S_IDLE;
                    end
                end
            endcase
        end
    end
endmodule