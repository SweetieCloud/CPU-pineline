`timescale 1ns / 1ps

// =============================================================================
// CONSTRAINED-RANDOM TESTBENCH: RV32IM PIPELINE VS PYTHON GOLDEN REFERENCE MODEL
// =============================================================================

module soc_random_tb;

    localparam CLK_PERIOD = 20; // 50 MHz
    reg clk;
    reg rst_n;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    reg  [3:0] sw;
    reg  [3:0] btn;
    wire ecall_halt;

    integer pass_count;
    integer fail_count;

    assign uart_rx = uart_tx; // loopback

    soc_top #(
        .ADDR_WIDTH   (32),
        .DATA_WIDTH   (32),
        .CLK_FREQ_HZ  (50_000_000),
        .BAUD_RATE    (115_200),
        .BOOT_HEX_FILE("random_test.hex")
    ) dut (
        .i_clk       (clk),
        .i_rst_n     (rst_n),
        .o_uart_tx   (uart_tx),
        .i_uart_rx   (uart_rx),
        .o_led       (led),
        .i_sw        (sw),
        .i_btn       (btn),
        .o_ecall_halt(ecall_halt)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING CONSTRAINED-RANDOM TEST VS RV32IM PYTHON GOLDEN MODEL");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        sw = 4'b0;
        btn = 4'b0;
        pass_count = 0;
        fail_count = 0;

        #(CLK_PERIOD * 10);
        rst_n = 1;

        fork
            begin
                wait (ecall_halt == 1'b1);
                $display("\n[INFO] ECALL Halt asserted. Constrained random execution completed.");
            end
            begin
                #(CLK_PERIOD * 50000); // 1 ms watchdog
                $fatal(1, "[ERROR] TIMEOUT! CPU did not reach ECALL Halt within 50,000 cycles.");
            end
        join_any
        disable fork;

        #(CLK_PERIOD * 5);

        $display("-------------------------------------------------------------------------------");
        $display("   SCOREBOARD CHECKING ARCHITECTURAL REGISTERS AGAINST GOLDEN MODEL:");
        $display("-------------------------------------------------------------------------------");
`include "golden_checks.vh"
        $display("-------------------------------------------------------------------------------");
        $display("   RANDOM TEST RESULTS: %0d / 32 REGISTERS MATCHED GOLDEN MODEL (Fails: %0d)", pass_count, fail_count);
        $display("-------------------------------------------------------------------------------");

        if (fail_count == 0 && pass_count == 32) begin
            $display("[SUCCESS] CONSTRAINED-RANDOM TEST PASSED (100%% MATCH WITH GOLDEN MODEL)!\n");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] CONSTRAINED-RANDOM TEST REGISTER MISMATCH DETECTED!");
        end
    end

endmodule
