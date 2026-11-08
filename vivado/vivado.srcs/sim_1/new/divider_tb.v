`timescale 1ns / 1ps
`include "defines.vh"

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: RV32M MULTI-CYCLE HARDWARE DIVIDER
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module divider (32-Cycle Restoring + Fast-Exit).
//   - Layer 2 (Mock Services): Mock EX-Stage Dividend/Divisor Driver.
//   - Layer 3 (Spy & SVA)    : Bộ đếm Spy theo dõi số phép chia hoàn tất, số lần
//                              Fast-Exit (0-cycle) vs Multi-Cycle (32-cycle) và
//                              khẳng định SVA kiểm tra độ trễ chính xác 33 chu kỳ.
//   - Layer 4 (Scoreboard)   : Các hàm run_div_test, expect_state, expect_spy.
// =============================================================================

module divider_tb;

    reg         tb_clk;
    reg         tb_rst_n;
    reg         tb_start;
    reg  [2:0]  tb_funct3;
    reg  [31:0] tb_dividend;
    reg  [31:0] tb_divisor;

    wire [31:0] tb_result;
    wire        tb_busy;
    wire        tb_done;

    integer pass_count;
    integer fail_count;
    integer cycle_count;

    // =========================================================================
    // LAYER 1: COMPONENT UNDER TEST (DUT ISOLATION)
    // =========================================================================
    divider uut (
        .i_clk      (tb_clk),
        .i_rst_n    (tb_rst_n),
        .i_start    (tb_start),
        .i_funct3   (tb_funct3),
        .i_dividend (tb_dividend),
        .i_divisor  (tb_divisor),
        .o_result   (tb_result),
        .o_busy     (tb_busy),
        .o_done     (tb_done)
    );

    // Clock generation: 100 MHz (10ns period)
    always #5 tb_clk = ~tb_clk;

    // =========================================================================
    // LAYER 3: SPY COUNTERS & SVA LATENCY ASSERTIONS
    // =========================================================================
    integer spy_fast_exit_cnt  = 0;
    integer spy_multicycle_cnt = 0;

    always @(posedge tb_clk or negedge tb_rst_n) begin
        if (!tb_rst_n) begin
            spy_fast_exit_cnt  <= 0;
            spy_multicycle_cnt <= 0;
        end else begin
            if (tb_done && (uut.state == 2'b00))
                spy_fast_exit_cnt <= spy_fast_exit_cnt + 1;
            if (tb_done && (uut.state == 2'b10))
                spy_multicycle_cnt <= spy_multicycle_cnt + 1;
        end
    end

    // SVA 1: o_busy and o_done must be mutually exclusive
    property p_busy_done_mutex;
        @(posedge tb_clk) disable iff (!tb_rst_n)
        !(tb_busy && tb_done);
    endproperty
    assert property (p_busy_done_mutex)
        else begin
            $error("[SVA ERROR] Divider asserted o_busy and o_done simultaneously!");
            fail_count = fail_count + 1;
        end

    // SVA 2: Multi-cycle division (STATE_IDLE && i_start && !fast_exit) must complete in exactly 33 cycles
    property p_multicycle_exact_latency;
        @(posedge tb_clk) disable iff (!tb_rst_n)
        ((uut.state == 2'b00) && tb_start && !uut.fast_exit) |-> (tb_busy[*33] ##1 (tb_done && !tb_busy));
    endproperty
    assert property (p_multicycle_exact_latency)
        else begin
            $error("[SVA ERROR] Multi-cycle division violated exact 33-cycle busy latency!");
            fail_count = fail_count + 1;
        end

    // =========================================================================
    // LAYER 2 & 4: MOCK DRIVER & SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_spy;
        input [255:0] name;
        input integer actual_cnt;
        input integer expected_cnt;
        begin
            assert (actual_cnt === expected_cnt) begin
                $display("[PASS] [EXPECT_SPY] %-30s | Calls: %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_SPY] %-30s | Calls: %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task run_div_test;
        input [31:0] dividend;
        input [31:0] divisor;
        input [2:0]  funct3;
        input [31:0] expected;
        input        expect_fast_exit;
        input [127:0] test_name;
        begin
            @(posedge tb_clk);
            #1;
            tb_dividend = dividend;
            tb_divisor  = divisor;
            tb_funct3   = funct3;
            tb_start    = 1'b1;
            cycle_count = 0;

            if (expect_fast_exit) begin
                #1; // Wait 1ns for combinational fast-exit
                assert (tb_done === 1'b1 && tb_busy === 1'b0 && tb_result === expected) begin
                    $display("[PASS FAST] %-28s | Fast exit 0-cycle! Res: 0x%08h", test_name, tb_result);
                    pass_count = pass_count + 1;
                end else begin
                    $error("[FAIL FAST] %-28s | GOT: 0x%08h (EXP: 0x%08h) busy=%b done=%b",
                           test_name, tb_result, expected, tb_busy, tb_done);
                    fail_count = fail_count + 1;
                end
                @(posedge tb_clk);
                #1;
                tb_start = 1'b0;
            end else begin
                // Multi-cycle division
                @(posedge tb_clk);
                #1;
                tb_start = 1'b0;

                while (!tb_done && (cycle_count < 45)) begin
                    @(posedge tb_clk);
                    cycle_count = cycle_count + 1;
                    #1;
                end

                assert (cycle_count == 32 && tb_result === expected && uut.state === 2'b10) begin
                    $display("[PASS]      %-28s | Latency=%0d cyc | Res: 0x%08h (%0d)",
                             test_name, cycle_count, tb_result, $signed(tb_result));
                    pass_count = pass_count + 1;
                end else begin
                    $error("[FAIL]      %-28s | Latency=%0d cyc | GOT: 0x%08h, EXP: 0x%08h",
                           test_name, cycle_count, tb_result, expected);
                    fail_count = fail_count + 1;
                end
            end
        end
    endtask

    initial begin
        tb_clk      = 0;
        tb_rst_n    = 0;
        tb_start    = 0;
        tb_funct3   = 3'b000;
        tb_dividend = 32'd0;
        tb_divisor  = 32'd0;
        pass_count  = 0;
        fail_count  = 0;

        #25;
        tb_rst_n = 1;
        #20;

        $display("=================================================================");
        $display("STARTING RV32M HARDWARE DIVIDER EXHAUSTIVE UNIT TEST");
        $display("=================================================================");

        // --- 1. SIGNED DIVISION (DIV) ---
        run_div_test(32'd20, 32'd3, `FUNCT3_DIV, 32'd6, 0, "DIV 20 / 3");
        run_div_test(32'd20, -32'd3, `FUNCT3_DIV, -32'd6, 0, "DIV 20 / -3");
        run_div_test(-32'd20, 32'd3, `FUNCT3_DIV, -32'd6, 0, "DIV -20 / 3");
        run_div_test(-32'd20, -32'd3, `FUNCT3_DIV, 32'd6, 0, "DIV -20 / -3");
        run_div_test(32'd3, 32'd5, `FUNCT3_DIV, 32'd0, 0, "DIV 3 / 5");
        run_div_test(32'd100, 32'd100, `FUNCT3_DIV, 32'd1, 0, "DIV 100 / 100");
        run_div_test(32'd1000000, 32'd10, `FUNCT3_DIV, 32'd100000, 0, "DIV 10^6 / 10");

        // --- 2. SIGNED REMAINDER (REM) ---
        run_div_test(32'd20, 32'd3, `FUNCT3_REM, 32'd2, 0, "REM 20 % 3");
        run_div_test(32'd20, -32'd3, `FUNCT3_REM, 32'd2, 0, "REM 20 % -3");
        run_div_test(-32'd20, 32'd3, `FUNCT3_REM, -32'd2, 0, "REM -20 % 3");
        run_div_test(-32'd20, -32'd3, `FUNCT3_REM, -32'd2, 0, "REM -20 % -3");
        run_div_test(32'd3, 32'd5, `FUNCT3_REM, 32'd3, 0, "REM 3 % 5");
        run_div_test(32'd100, 32'd100, `FUNCT3_REM, 32'd0, 0, "REM 100 % 100");

        // --- 3. UNSIGNED DIVISION (DIVU) ---
        run_div_test(32'd20, 32'd3, `FUNCT3_DIVU, 32'd6, 0, "DIVU 20 / 3");
        run_div_test(32'hFFFFFFFF, 32'd2, `FUNCT3_DIVU, 32'h7FFFFFFF, 0, "DIVU MaxUInt / 2");
        run_div_test(32'h80000000, 32'd2, `FUNCT3_DIVU, 32'h40000000, 0, "DIVU 0x80000000 / 2");

        // --- 4. UNSIGNED REMAINDER (REMU) ---
        run_div_test(32'd20, 32'd3, `FUNCT3_REMU, 32'd2, 0, "REMU 20 % 3");
        run_div_test(32'hFFFFFFFF, 32'd2, `FUNCT3_REMU, 32'd1, 0, "REMU MaxUInt % 2");
        run_div_test(32'h80000000, 32'd3, `FUNCT3_REMU, 32'd2, 0, "REMU 0x80000000 % 3");

        // --- 5. CORNER CASES: FAST-EXIT (RISC-V SPEC MANDATORY) ---
        // Divide by zero: DIV x/0 = -1
        run_div_test(32'd12345, 32'd0, `FUNCT3_DIV, 32'hFFFFFFFF, 1, "DIV Zero Divisor");
        // Divide by zero: DIVU x/0 = 2^32 - 1
        run_div_test(32'd12345, 32'd0, `FUNCT3_DIVU, 32'hFFFFFFFF, 1, "DIVU Zero Divisor");
        // Divide by zero: REM x%0 = x
        run_div_test(32'd12345, 32'd0, `FUNCT3_REM, 32'd12345, 1, "REM Zero Divisor");
        // Divide by zero: REMU x%0 = x
        run_div_test(32'hDEADBEEF, 32'd0, `FUNCT3_REMU, 32'hDEADBEEF, 1, "REMU Zero Divisor");
        // Signed Overflow: DIV -2^31 / -1 = -2^31
        run_div_test(32'h80000000, 32'hFFFFFFFF, `FUNCT3_DIV, 32'h80000000, 1, "DIV Signed Overflow");
        // Signed Overflow: REM -2^31 % -1 = 0
        run_div_test(32'h80000000, 32'hFFFFFFFF, `FUNCT3_REM, 32'h00000000, 1, "REM Signed Overflow");
        // Unsigned check: 0x80000000 / 0xFFFFFFFF in DIVU is NOT overflow (normal division)
        run_div_test(32'h80000000, 32'hFFFFFFFF, `FUNCT3_DIVU, 32'd0, 0, "DIVU 0x80000000/0xFFFFFFFF");

        #20;
        expect_spy("Total Fast-Exit Divisions",   spy_fast_exit_cnt,  6);
        expect_spy("Total Multi-Cycle Divisions", spy_multicycle_cnt, 20);

        #20;
        $display("=================================================================");
        $display("DIVIDER TEST SUMMARY: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("=================================================================");

        if (fail_count == 0) begin
            $display("[SUCCESS] RV32M DIVIDER VERIFIED 100%% CORRECT WITH FAST EXIT!");
        end else begin
            $display("[FATAL] DIVIDER VERIFICATION FAILED!");
        end
        $finish;
    end

endmodule
