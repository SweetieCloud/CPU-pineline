`timescale 1ns / 1ps
`include "defines.vh"

module regfile_tb;

    reg         clk;
    reg         rst_n;
    reg  [4:0]  rs1_addr;
    reg  [4:0]  rs2_addr;
    reg         reg_write;
    reg  [4:0]  rd_addr;
    reg  [31:0] rd_data;

    wire [31:0] rs1_data;
    wire [31:0] rs2_data;

    // Instantiate Register File RV32I
    register_file uut (
        .i_clk       (clk),
        .i_rst_n     (rst_n),
        .i_rs1_addr  (rs1_addr),
        .o_rs1_data  (rs1_data),
        .i_rs2_addr  (rs2_addr),
        .o_rs2_data  (rs2_data),
        .i_reg_write (reg_write),
        .i_rd_addr   (rd_addr),
        .i_rd_data   (rd_data)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    integer errors = 0;

    initial begin
        $display("\n=== STARTING RV32I REGISTER FILE 32-BIT UNIT TEST ===");

        rst_n = 0; reg_write = 0; rs1_addr = 0; rs2_addr = 0; rd_addr = 0; rd_data = 0;
        #15;
        rst_n = 1;
        #10;

        // Test 1: Hardwired Zero Register x0
        rd_addr = 5'd0; rd_data = 32'hDEADBEEF; reg_write = 1;
        #10;
        reg_write = 0; rs1_addr = 5'd0;
        #1;
        if (rs1_data !== 32'd0) begin
            $display("[FAIL] x0 written with value 0x%08H!", rs1_data); errors = errors + 1;
        end else $display("[PASS] Register x0 Hardwired Protection: x0 == 0");

        // Test 2: Normal Write & Read
        rd_addr = 5'd1; rd_data = 32'hA5A55A5A; reg_write = 1;
        #10;
        reg_write = 0; rs1_addr = 5'd1;
        #1;
        if (rs1_data !== 32'hA5A55A5A) begin
            $display("[FAIL] Normal Read/Write: x1 = 0x%08H", rs1_data); errors = errors + 1;
        end else $display("[PASS] Normal Read/Write: x1 = 0xA5A55A5A");

        // Test 3: Internal Forwarding / Write-Through (Read and Write in same cycle)
        rd_addr = 5'd2; rd_data = 32'h12345678; reg_write = 1; rs1_addr = 5'd2;
        #1;
        if (rs1_data !== 32'h12345678) begin
            $display("[FAIL] Internal Forwarding (Write-Through) Failed! Value: 0x%08H", rs1_data); errors = errors + 1;
        end else $display("[PASS] Internal Forwarding (Write-Through): Same-cycle Read/Write x2 = 0x12345678");

        #9;
        reg_write = 0;

        // Test 4: Dual Read Ports (rs1 and rs2 simultaneously)
        rd_addr = 5'd3; rd_data = 32'hCAFEBABE; reg_write = 1;
        #10;
        reg_write = 0; rs1_addr = 5'd1; rs2_addr = 5'd3;
        #1;
        if (rs1_data !== 32'hA5A55A5A || rs2_data !== 32'hCAFEBABE) begin
            $display("[FAIL] Dual Read Ports: rs1=0x%08H, rs2=0x%08H", rs1_data, rs2_data); errors = errors + 1;
        end else $display("[PASS] Dual Read Ports: rs1(x1) = 0xA5A55A5A, rs2(x3) = 0xCAFEBABE");

        $display("=== REGISTER FILE UNIT TEST DONE. TOTAL ERRORS: %0d ===\n", errors);
        $finish;
    end

endmodule
