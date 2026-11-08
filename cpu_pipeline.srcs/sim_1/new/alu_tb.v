`timescale 1ns / 1ps
`include "defines.vh"

module alu_tb;

    // Inputs
    reg  [31:0] i_in_a;
    reg  [31:0] i_in_b;
    reg  [3:0]  i_alu_op;

    // Outputs
    wire [31:0] o_result;
    wire        o_zero;

    // Instantiate RV32I ALU
    alu #(
        .DATA_WIDTH(32)
    ) uut (
        .i_in_a   (i_in_a),
        .i_in_b   (i_in_b),
        .i_alu_op (i_alu_op),
        .o_result (o_result),
        .o_zero   (o_zero)
    );

    integer errors = 0;

    initial begin
        $display("\n=== STARTING RV32I ALU 32-BIT UNIT TEST ===");

        // Test 1: ADD
        i_in_a = 32'd50; i_in_b = 32'd100; i_alu_op = `ALU_ADD;
        #10;
        if (o_result !== 32'd150 || o_zero !== 1'b0) begin
            $display("[FAIL] ADD: %0d != 150", o_result); errors = errors + 1;
        end else $display("[PASS] ADD: 50 + 100 = 150");

        // Test 2: SUB & ZERO flag
        i_in_a = 32'd200; i_in_b = 32'd200; i_alu_op = `ALU_SUB;
        #10;
        if (o_result !== 32'd0 || o_zero !== 1'b1) begin
            $display("[FAIL] SUB: %0d != 0", o_result); errors = errors + 1;
        end else $display("[PASS] SUB (Zero Flag): 200 - 200 = 0 (Zero=1)");

        // Test 3: SLT (Signed Less Than)
        i_in_a = -32'd10; i_in_b = 32'd5; i_alu_op = `ALU_SLT;
        #10;
        if (o_result !== 32'd1) begin
            $display("[FAIL] SLT: %0d != 1", o_result); errors = errors + 1;
        end else $display("[PASS] SLT: -10 < 5 = 1");

        // Test 4: SLTU (Unsigned Less Than)
        i_in_a = -32'd10; // Rất lớn trong unsigned (0xFFFFFFF6)
        i_in_b = 32'd5;
        i_alu_op = `ALU_SLTU;
        #10;
        if (o_result !== 32'd0) begin
            $display("[FAIL] SLTU: %0d != 0", o_result); errors = errors + 1;
        end else $display("[PASS] SLTU: 0xFFFFFFF6 < 5 = 0");

        // Test 5: SLL (Shift Left Logical)
        i_in_a = 32'h0000000F; i_in_b = 32'd4; i_alu_op = `ALU_SLL;
        #10;
        if (o_result !== 32'h000000F0) begin
            $display("[FAIL] SLL: 0x%08H != 0x000000F0", o_result); errors = errors + 1;
        end else $display("[PASS] SLL: 0x0F << 4 = 0xF0");

        // Test 6: SRA (Shift Right Arithmetic)
        i_in_a = 32'hF0000000; i_in_b = 32'd4; i_alu_op = `ALU_SRA;
        #10;
        if (o_result !== 32'hFF000000) begin
            $display("[FAIL] SRA: 0x%08H != 0xFF000000", o_result); errors = errors + 1;
        end else $display("[PASS] SRA: 0xF0000000 >>> 4 = 0xFF000000");

        // Test 7: LUI (COPY_B)
        i_in_a = 32'h12345678; i_in_b = 32'hABCD0000; i_alu_op = `ALU_COPY_B;
        #10;
        if (o_result !== 32'hABCD0000) begin
            $display("[FAIL] COPY_B: 0x%08H != 0xABCD0000", o_result); errors = errors + 1;
        end else $display("[PASS] COPY_B (LUI): Result = 0xABCD0000");

        // Test 8: XOR
        i_in_a = 32'hAAAA5555; i_in_b = 32'hFFFF0000; i_alu_op = `ALU_XOR;
        #10;
        if (o_result !== 32'h55555555) begin
            $display("[FAIL] XOR: 0x%08X != 0x55555555", o_result); errors = errors + 1;
        end else $display("[PASS] XOR: 0xAAAA5555 ^ 0xFFFF0000 = 0x55555555");

        // Test 9: SRL (Shift Right Logical)
        i_in_a = 32'h80000000; i_in_b = 32'd4; i_alu_op = `ALU_SRL;
        #10;
        if (o_result !== 32'h08000000) begin
            $display("[FAIL] SRL: 0x%08X != 0x08000000", o_result); errors = errors + 1;
        end else $display("[PASS] SRL: 0x80000000 >> 4 = 0x08000000");

        // Test 10: OR
        i_in_a = 32'h0F0F0F0F; i_in_b = 32'hF0F0F0F0; i_alu_op = `ALU_OR;
        #10;
        if (o_result !== 32'hFFFFFFFF) begin
            $display("[FAIL] OR: 0x%08X != 0xFFFFFFFF", o_result); errors = errors + 1;
        end else $display("[PASS] OR: 0x0F0F0F0F | 0xF0F0F0F0 = 0xFFFFFFFF");

        // Test 11: AND
        i_in_a = 32'hFFFF0000; i_in_b = 32'h00FFFF00; i_alu_op = `ALU_AND;
        #10;
        if (o_result !== 32'h00FF0000) begin
            $display("[FAIL] AND: 0x%08X != 0x00FF0000", o_result); errors = errors + 1;
        end else $display("[PASS] AND: 0xFFFF0000 & 0x00FFFF00 = 0x00FF0000");

        // Test 12: Default Opcode Fallback
        i_in_a = 32'h12345678; i_in_b = 32'h87654321; i_alu_op = 4'hF; // Undefined
        #10;
        if (o_result !== 32'h00000000 || o_zero !== 1'b1) begin
            $display("[FAIL] DEFAULT: 0x%08X != 0", o_result); errors = errors + 1;
        end else $display("[PASS] DEFAULT: Fallback to 0 (Zero=1)");

        $display("=== ALU UNIT TEST DONE. TOTAL ERRORS: %0d ===\n", errors);
        $finish;
    end

endmodule
