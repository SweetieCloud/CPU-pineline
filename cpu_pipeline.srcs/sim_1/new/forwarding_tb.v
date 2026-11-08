`timescale 1ns / 1ps

module forwarding_tb;

    reg  [4:0] id_ex_rs1;
    reg  [4:0] id_ex_rs2;
    reg  [4:0] ex_mem_rd;
    reg        ex_mem_reg_write;
    reg  [4:0] mem_wb_rd;
    reg        mem_wb_reg_write;

    wire [1:0] forward_a;
    wire [1:0] forward_b;

    // Instantiate Forwarding Unit
    forwarding_unit uut (
        .i_id_ex_rs1        (id_ex_rs1),
        .i_id_ex_rs2        (id_ex_rs2),
        .i_ex_mem_rd        (ex_mem_rd),
        .i_ex_mem_reg_write (ex_mem_reg_write),
        .i_mem_wb_rd        (mem_wb_rd),
        .i_mem_wb_reg_write (mem_wb_reg_write),
        .o_forward_a        (forward_a),
        .o_forward_b        (forward_b)
    );

    integer errors = 0;

    initial begin
        $display("\n=== STARTING RV32I FORWARDING UNIT TEST ===");

        // Default state: No hazards
        id_ex_rs1 = 5'd1; id_ex_rs2 = 5'd2;
        ex_mem_rd = 5'd3; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd4; mem_wb_reg_write = 1'b1;
        #10;
        if (forward_a !== 2'b00 || forward_b !== 2'b00) begin
            $display("[FAIL] False forwarding triggered: A=%b, B=%b", forward_a, forward_b); errors = errors + 1;
        end else $display("[PASS] No Hazard - Default State (A=00, B=00)");

        // Test 1: EX/MEM Hazard on RS1 (forward_a = 2'b10)
        id_ex_rs1 = 5'd5; id_ex_rs2 = 5'd2;
        ex_mem_rd = 5'd5; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0; mem_wb_reg_write = 1'b0;
        #10;
        if (forward_a !== 2'b10) begin
            $display("[FAIL] EX Hazard on RS1: A=%b (Expected: 10)", forward_a); errors = errors + 1;
        end else $display("[PASS] EX Hazard on RS1: forward_a = 2'b10");

        // Test 2: MEM/WB Hazard on RS2 (forward_b = 2'b01)
        id_ex_rs1 = 5'd1; id_ex_rs2 = 5'd6;
        ex_mem_rd = 5'd7; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd6; mem_wb_reg_write = 1'b1;
        #10;
        if (forward_b !== 2'b01) begin
            $display("[FAIL] MEM Hazard on RS2: B=%b (Expected: 01)", forward_b); errors = errors + 1;
        end else $display("[PASS] MEM Hazard on RS2: forward_b = 2'b01");

        // Test 3: Double Hazard (Prioritize EX/MEM over MEM/WB)
        id_ex_rs1 = 5'd8; id_ex_rs2 = 5'd0;
        ex_mem_rd = 5'd8; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd8; mem_wb_reg_write = 1'b1;
        #10;
        if (forward_a !== 2'b10) begin
            $display("[FAIL] Double Hazard: A=%b (Expected: 10)", forward_a); errors = errors + 1;
        end else $display("[PASS] Double Hazard Resolution: Priority given to EX/MEM (2'b10)");

        // Test 4: Register x0 Protection (Never forward x0!)
        id_ex_rs1 = 5'd0; id_ex_rs2 = 5'd0;
        ex_mem_rd = 5'd0; ex_mem_reg_write = 1'b1;
        mem_wb_rd = 5'd0; mem_wb_reg_write = 1'b1;
        #10;
        if (forward_a !== 2'b00 || forward_b !== 2'b00) begin
            $display("[FAIL] x0 forwarded! A=%b, B=%b", forward_a, forward_b); errors = errors + 1;
        end else $display("[PASS] Register x0 Forwarding Protection: A=00, B=00");

        $display("=== FORWARDING UNIT TEST DONE. TOTAL ERRORS: %0d ===\n", errors);
        $finish;
    end

endmodule
