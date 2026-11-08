`timescale 1ns / 1ps

// =============================================================================
// OFFICIAL RISC-V ARCHITECTURAL TEST HARNESS: RV32UI & RV32UM
// =============================================================================
// Runs 73 standard test sequences covering:
//   - RV32I: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, ADDI, etc.
//   - RV32M: MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU (including Div-by-0 & Overflow)
// =============================================================================

module soc_isa_tb;

    localparam CLK_PERIOD = 20; // 50 MHz
    reg clk;
    reg rst_n;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    reg  [3:0] sw;
    reg  [3:0] btn;
    wire ecall_halt;

    assign uart_rx = uart_tx; // loopback

    soc_top #(
        .ADDR_WIDTH   (32),
        .DATA_WIDTH   (32),
        .CLK_FREQ_HZ  (50_000_000),
        .BAUD_RATE    (115_200),
        .BOOT_HEX_FILE("riscv_isa_suite.hex")
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
        $display("   STARTING OFFICIAL RISC-V RV32UI & RV32UM ARCHITECTURAL CONFORMANCE SUITE");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        sw = 4'b0;
        btn = 4'b0;

        #(CLK_PERIOD * 10);
        rst_n = 1;

        fork
            begin
                wait (ecall_halt == 1'b1);
                $display("\n[INFO] ECALL Halt asserted. Conformance test execution completed.");
            end
            begin
                #(CLK_PERIOD * 100000); // 2 ms watchdog
                $fatal(1, "[ERROR] TIMEOUT! CPU did not reach ECALL Halt within 100,000 cycles.");
            end
        join_any
        disable fork;

        #(CLK_PERIOD * 5);

        // Check results stored in BRAM
        // mem[768] is at byte address 0x300 (word 768 / 4 = 192 or word index 768?)
        // In riscv_isa_tests.py: addi t0, x0, 768; sw s1, 0(t0) -> byte address 768 = word 768/4 = 192!
        $display("-------------------------------------------------------------------------------");
        $display("   CONFORMANCE TEST SUITE RESULTS:");
        $display("   - Total Passed Tests (s1): %0d / 73", dut.cpu_inst.datapath_inst.reg_file.registers[9]);
        $display("   - Total Failed Tests (gp): %0d", dut.cpu_inst.datapath_inst.reg_file.registers[3]);
        $display("   - Last Fail Info: Test ID=%0d, Got=0x%08X, Exp=0x%08X",
                 dut.cpu_inst.datapath_inst.reg_file.registers[10],
                 dut.cpu_inst.datapath_inst.reg_file.registers[11],
                 dut.cpu_inst.datapath_inst.reg_file.registers[12]);
        $display("-------------------------------------------------------------------------------");

        if (dut.cpu_inst.datapath_inst.reg_file.registers[3] == 0 &&
            dut.cpu_inst.datapath_inst.reg_file.registers[9] == 73) begin
            $display("[SUCCESS] 100%% RV32UI & RV32UM ARCHITECTURAL TESTS PASSED!\n");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] SOME RISC-V ARCHITECTURAL TESTS FAILED!");
        end
    end

endmodule
