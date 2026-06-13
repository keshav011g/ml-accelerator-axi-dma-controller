`timescale 1ns / 1ps

module tb_ml_accelerator_top();

    reg clk; reg rst_n;
    
    // AXI Interfaces
    reg [5:0] s_axi_awaddr; reg s_axi_awvalid; wire s_axi_awready;
    reg [31:0] s_axi_wdata; reg [3:0] s_axi_wstrb; reg s_axi_wvalid; wire s_axi_wready;
    wire [1:0] s_axi_bresp; wire s_axi_bvalid; reg s_axi_bready;
    reg [5:0] s_axi_araddr; reg s_axi_arvalid; wire s_axi_arready;
    wire [31:0] s_axi_rdata; wire [1:0] s_axi_rresp; wire s_axi_rvalid; reg s_axi_rready;

    wire [31:0] m_axi_araddr; wire [7:0] m_axi_arlen; wire [2:0] m_axi_arsize;
    wire [1:0] m_axi_arburst; wire m_axi_arvalid; reg m_axi_arready;
    reg [31:0] m_axi_rdata; reg m_axi_rlast; reg m_axi_rvalid; wire m_axi_rready;

    wire [31:0] m_axi_awaddr; wire [7:0] m_axi_awlen; wire [2:0] m_axi_awsize;
    wire [1:0] m_axi_awburst; wire m_axi_awvalid; reg m_axi_awready;
    wire [31:0] m_axi_wdata; wire [3:0] m_axi_wstrb; wire m_axi_wlast;
    wire m_axi_wvalid; reg m_axi_wready;
    reg [1:0] m_axi_bresp; reg m_axi_bvalid; wire m_axi_bready;

    wire irq_done;
    reg [7:0] MAIN_RAM [0:2047]; 

    ml_accelerator_top uut (
        .clk(clk), .rst_n(rst_n),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb), .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        
        .m_axi_araddr(m_axi_araddr), .m_axi_arlen(m_axi_arlen), .m_axi_arsize(m_axi_arsize), .m_axi_arburst(m_axi_arburst),
        .m_axi_arvalid(m_axi_arvalid), .m_axi_arready(m_axi_arready), .m_axi_rdata(m_axi_rdata), .m_axi_rlast(m_axi_rlast),
        .m_axi_rvalid(m_axi_rvalid), .m_axi_rready(m_axi_rready),
        
        .m_axi_awaddr(m_axi_awaddr), .m_axi_awlen(m_axi_awlen), .m_axi_awsize(m_axi_awsize), .m_axi_awburst(m_axi_awburst),
        .m_axi_awvalid(m_axi_awvalid), .m_axi_awready(m_axi_awready), .m_axi_wdata(m_axi_wdata), .m_axi_wstrb(m_axi_wstrb),
        .m_axi_wlast(m_axi_wlast), .m_axi_wvalid(m_axi_wvalid), .m_axi_wready(m_axi_wready),
        .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(m_axi_bready),
        .irq_done(irq_done)
    );

    always #5 clk = ~clk;

    task axi_write;
        input [5:0] addr; input [31:0] data;
        begin
            @(posedge clk); s_axi_awaddr = addr; s_axi_awvalid = 1;
            s_axi_wdata = data; s_axi_wvalid = 1; s_axi_wstrb = 4'hF;
            wait (s_axi_awready && s_axi_wready);
            @(posedge clk); s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 1;
            wait (s_axi_bvalid); @(posedge clk); s_axi_bready = 0;
        end
    endtask

    task axi_read;
        input [5:0] addr; output [31:0] data;
        begin
            @(posedge clk); s_axi_araddr = addr; s_axi_arvalid = 1;
            wait (s_axi_arready); @(posedge clk); s_axi_arvalid = 0; s_axi_rready = 1;
            wait (s_axi_rvalid); data = s_axi_rdata; @(posedge clk); s_axi_rready = 0;
        end
    endtask

    integer i, ram_r_ptr, burst_r_count, ram_w_ptr;
    always @(posedge clk) begin
        if (!rst_n) begin
            m_axi_arready <= 0; m_axi_rvalid <= 0; burst_r_count <= 0;
            m_axi_awready <= 0; m_axi_wready <= 0; m_axi_bvalid <= 0;
        end else begin
            if (m_axi_arvalid && !m_axi_arready && !m_axi_rvalid) begin 
                m_axi_arready <= 1; 
                ram_r_ptr <= m_axi_araddr + 4; 
                burst_r_count <= m_axi_arlen + 1; 
                m_axi_rdata <= {MAIN_RAM[m_axi_araddr+3], MAIN_RAM[m_axi_araddr+2], MAIN_RAM[m_axi_araddr+1], MAIN_RAM[m_axi_araddr]};
                m_axi_rvalid <= 1;
                m_axi_rlast <= (m_axi_arlen == 0);
            end else begin
                m_axi_arready <= 0;
            end
            
            if (m_axi_rvalid && m_axi_rready) begin
                if (burst_r_count == 1) begin 
                    m_axi_rvalid <= 0; 
                    m_axi_rlast <= 0; 
                end else begin
                    burst_r_count <= burst_r_count - 1;
                    ram_r_ptr <= ram_r_ptr + 4;
                    m_axi_rdata <= {MAIN_RAM[ram_r_ptr+3], MAIN_RAM[ram_r_ptr+2], MAIN_RAM[ram_r_ptr+1], MAIN_RAM[ram_r_ptr]};
                    m_axi_rlast <= (burst_r_count == 2);
                end
            end

            if (m_axi_awvalid && !m_axi_awready) begin m_axi_awready <= 1; ram_w_ptr <= m_axi_awaddr; end 
            else m_axi_awready <= 0;

            m_axi_wready <= 1; 
            if (m_axi_wvalid) begin
                if (ram_w_ptr < 512 + 5*4) $display("[DBG] Write @%0d: wdata=0x%08h (signed24=%0d)", ram_w_ptr, m_axi_wdata, $signed(m_axi_wdata[23:0]));
                MAIN_RAM[ram_w_ptr]   <= m_axi_wdata[7:0];
                MAIN_RAM[ram_w_ptr+1] <= m_axi_wdata[15:8];
                MAIN_RAM[ram_w_ptr+2] <= m_axi_wdata[23:16];
                MAIN_RAM[ram_w_ptr+3] <= m_axi_wdata[31:24];
                ram_w_ptr <= ram_w_ptr + 4;
            end

            if (m_axi_wvalid && m_axi_wlast) m_axi_bvalid <= 1;
            else if (m_axi_bready && m_axi_bvalid) m_axi_bvalid <= 0;
        end
    end

    reg signed [7:0] A_mat [0:15][0:15];
    reg signed [7:0] B_mat [0:15][0:15];
    reg signed [23:0] C_mat [0:15][0:15];
    integer r, c, k, err_cnt;
    reg signed [23:0] sum;
    reg [31:0] read_val, hw_res;

    initial begin
        $dumpfile("waveform_soc.vcd"); $dumpvars(0, tb_ml_accelerator_top);
        clk = 0; rst_n = 0;
        s_axi_awvalid = 0; s_axi_wvalid = 0; s_axi_bready = 0;
        s_axi_arvalid = 0; s_axi_rready = 0;
        
        for(i = 0; i < 2048; i = i + 1) MAIN_RAM[i] = 8'd0;
        
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                MAIN_RAM[256 + r*16 + c] = r + c;         // Input Matrix A
                MAIN_RAM[0 + r*16 + c]   = r - c;         // Weight Matrix B
            end
        end

        for(r=0; r<16; r=r+1) for(c=0; c<16; c=c+1) begin
            A_mat[r][c] = MAIN_RAM[256 + r*16 + c]; 
            B_mat[r][c] = MAIN_RAM[0 + r*16 + c];   
        end
        
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                sum = 0;
                for(k=0; k<16; k=k+1) sum = sum + $signed(A_mat[r][k]) * $signed(B_mat[k][c]);
                C_mat[r][c] = sum;
            end
        end

        #30 rst_n = 1;
        $display("\n========================================================");
        $display("   STARTING HARDWARE ACCELERATOR SIMULATION");
        $display("========================================================\n");

        axi_write(6'h14, 32'd0);    // Weight Base = 0
        $display("[CONFIG] AXI Write to 0x14 (Weight Base)  = 0");
        axi_write(6'h18, 32'd256);  // Input Base = 256
        $display("[CONFIG] AXI Write to 0x18 (Input Base)   = 256");
        axi_write(6'h1C, 32'd512);  // Output Base = 512 
        $display("[CONFIG] AXI Write to 0x1C (Output Base)  = 512");
        
        $display("--- Triggering Hardware ---");
        axi_write(6'h00, 32'h01);  
        $display("[CONFIG] AXI Write to 0x00 (Control Reg)  = 1 (Start)");
        
        read_val = 0;
        while ((read_val & 32'h0000_0002) == 0) begin
            axi_read(6'h04, read_val);
            if ((read_val & 32'h0000_0002) == 0) #1000;
        end
        
        $display("\n[SUCCESS] Hardware Finished Computing and Writing to RAM!");
        $display("\n--- Step 5: Self-Checking Data Verification ---");
        
        err_cnt = 0;
        for(r=0; r<16; r=r+1) begin
            for(c=0; c<16; c=c+1) begin
                hw_res = {MAIN_RAM[512 + (r*16+c)*4 + 3], MAIN_RAM[512 + (r*16+c)*4 + 2], 
                          MAIN_RAM[512 + (r*16+c)*4 + 1], MAIN_RAM[512 + (r*16+c)*4]};
                
                if ($signed(hw_res[23:0]) !== C_mat[r][c]) begin
                    $display("MISMATCH at [%2d][%2d] | Expected: %6d | Got: %6d  <-- ERROR", r, c, C_mat[r][c], $signed(hw_res[23:0]));
                    err_cnt = err_cnt + 1;
                end else begin
                    $display("MATCH    at [%2d][%2d] | Expected: %6d | Got: %6d", r, c, C_mat[r][c], $signed(hw_res[23:0]));
                end
            end
        end

        if (err_cnt == 0) $display(">>> ALL 256 MAC RESULTS MATCH PERFECTLY! TEST PASSED! <<<");
        else $display(">>> FAILED with %d errors <<<", err_cnt);

        $display("\n========================================================\n");
        $finish;
    end
endmodule