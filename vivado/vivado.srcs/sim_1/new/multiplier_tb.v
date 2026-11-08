`timescale 1ns / 1ps
`include "defines.vh"

module multiplier_tb;

    reg  [31:0] tb_a;
    reg  [31:0] tb_b;
    reg  [2:0]  tb_funct3;
    wire [31:0] tb_result;

    integer pass_count;
    integer fail_count;
    integer spy_mul_calls;

    multiplier uut (
        .i_a      (tb_a),
        .i_b      (tb_b),
        .i_funct3 (tb_funct3),
        .o_result (tb_result)
    );

    task check_mul;
        input [31:0] a;
        input [31:0] b;
        input [2:0]  funct3;
        input [31:0] expected;
        input [127:0] test_name;
        begin
            tb_a          = a;
            tb_b          = b;
            tb_funct3     = funct3;
            spy_mul_calls = spy_mul_calls + 1;
            #10;
            assert (tb_result === expected) begin
                $display("[PASS] [EXPECT_EQ] %-22s | a=0x%08h, b=0x%08h, funct3=%b | res=0x%08h", 
                         test_name, a, b, funct3, tb_result);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_EQ] %-22s | a=0x%08h, b=0x%08h, funct3=%b | GOT: 0x%08h, EXP: 0x%08h", 
                       test_name, a, b, funct3, tb_result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count    = 0;
        fail_count    = 0;
        spy_mul_calls = 0;

        $display("=================================================================");
        $display("STARTING RV32M MULTIPLIER EXHAUSTIVE UNIT TEST");
        $display("=================================================================");

        // --- 1. MUL (Low 32-bit) ---
        check_mul(32'd7, 32'd6, `FUNCT3_MUL, 32'd42, "MUL Pos*Pos");
        check_mul(32'd10, -32'd5, `FUNCT3_MUL, -32'd50, "MUL Pos*Neg");
        check_mul(-32'd20, -32'd3, `FUNCT3_MUL, 32'd60, "MUL Neg*Neg");
        check_mul(32'h12345678, 32'd0, `FUNCT3_MUL, 32'd0, "MUL Zero");
        check_mul(32'h12345678, 32'd1, `FUNCT3_MUL, 32'h12345678, "MUL One");
        check_mul(32'd100000, 32'd100000, `FUNCT3_MUL, 32'h540BE400, "MUL Wrap");
        check_mul(32'h80000000, 32'hFFFFFFFF, `FUNCT3_MUL, 32'h80000000, "MUL MinInt*-1");

        // --- 2. MULH (High 32-bit Signed * Signed) ---
        check_mul(32'd2, 32'd3, `FUNCT3_MULH, 32'd0, "MULH Small Pos");
        check_mul(32'h7FFFFFFF, 32'h7FFFFFFF, `FUNCT3_MULH, 32'h3FFFFFFF, "MULH MaxPos*MaxPos");
        check_mul(32'h80000000, 32'h80000000, `FUNCT3_MULH, 32'h40000000, "MULH MinInt*MinInt");
        check_mul(32'hFFFFFFFF, 32'd1, `FUNCT3_MULH, 32'hFFFFFFFF, "MULH Neg1*Pos1");
        check_mul(32'h80000000, 32'd1, `FUNCT3_MULH, 32'hFFFFFFFF, "MULH MinInt*Pos1");
        check_mul(32'h7FFFFFFF, 32'hFFFFFFFF, `FUNCT3_MULH, 32'hFFFFFFFF, "MULH MaxPos*Neg1");

        // --- 3. MULHSU (High 32-bit Signed rs1 * Unsigned rs2) ---
        check_mul(32'hFFFFFFFF, 32'd1, `FUNCT3_MULHSU, 32'hFFFFFFFF, "MULHSU Neg1*Pos1");
        check_mul(32'hFFFFFFFF, 32'hFFFFFFFF, `FUNCT3_MULHSU, 32'hFFFFFFFF, "MULHSU Neg1*MaxUInt");
        check_mul(32'h7FFFFFFF, 32'hFFFFFFFF, `FUNCT3_MULHSU, 32'h7FFFFFFE, "MULHSU MaxInt*MaxUInt");
        check_mul(32'h80000000, 32'd2, `FUNCT3_MULHSU, 32'hFFFFFFFF, "MULHSU MinInt*2");
        check_mul(32'd5, 32'd5, `FUNCT3_MULHSU, 32'd0, "MULHSU Small Pos");

        // --- 4. MULHU (High 32-bit Unsigned * Unsigned) ---
        check_mul(32'hFFFFFFFF, 32'hFFFFFFFF, `FUNCT3_MULHU, 32'hFFFFFFFE, "MULHU MaxUInt*MaxUInt");
        check_mul(32'h80000000, 32'h80000000, `FUNCT3_MULHU, 32'h40000000, "MULHU HalfUInt*HalfUInt");
        check_mul(32'hFFFFFFFF, 32'd1, `FUNCT3_MULHU, 32'd0, "MULHU MaxUInt*1");
        check_mul(32'd10, 32'd20, `FUNCT3_MULHU, 32'd0, "MULHU Small UInt");

        assert (spy_mul_calls === 22) begin
            $display("[PASS] [EXPECT_SPY] Total Multiplier Evaluations = %0d (Exp: 22)", spy_mul_calls);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [EXPECT_SPY] Total Multiplier Evaluations = %0d (Exp: 22)", spy_mul_calls);
            fail_count = fail_count + 1;
        end

        #20;
        $display("=================================================================");
        $display("MULTIPLIER TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=================================================================");

        if (fail_count == 0) begin
            $display("[SUCCESS] RV32M MULTIPLIER VERIFIED 100%% CORRECT!");
        end else begin
            $display("[FATAL] MULTIPLIER VERIFICATION FAILED!");
        end
        $finish;
    end

endmodule
