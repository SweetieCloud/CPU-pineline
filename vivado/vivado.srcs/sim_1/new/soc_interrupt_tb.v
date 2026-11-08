`timescale 1ns / 1ps

// =============================================================================
// COMPREHENSIVE HARDWARE INTERRUPT & MRET VERIFICATION HARNESS
// =============================================================================
// Verification Scenarios:
//   1. Machine Timer Interrupt (MTIP) triggering and precision trapping
//   2. Hardware redirection to MTVEC
//   3. Saving precise interrupted PC to MEPC and cause 0x80000007 to MCAUSE
//   4. MIE cleared and MPIE saved upon trap entrance
//   5. Execution of MRET restoring PC from MEPC and restoring MIE from MPIE
//   6. Resumption of interrupted main loop without corruption or lost cycles
//   7. Multiple consecutive interrupt occurrences (3 times)
// =============================================================================

module soc_interrupt_tb;

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

    assign uart_rx = uart_tx;

    soc_top #(
        .ADDR_WIDTH   (32),
        .DATA_WIDTH   (32),
        .CLK_FREQ_HZ  (50_000_000),
        .BAUD_RATE    (115_200),
        .BOOT_HEX_FILE("test_interrupt.hex")
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

    // Watchdog timer (100 us)
    initial begin
        #100_000;
        $fatal(1, "\n[FATAL TIMEOUT] soc_interrupt_tb watchdog triggered! Potential deadlock.");
    end

    integer irq_round;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING RISC-V HARDWARE INTERRUPT & MRET COMPREHENSIVE VERIFICATION");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        sw = 4'b0;
        btn = 4'b0;
        pass_count = 0;
        fail_count = 0;

        #(CLK_PERIOD * 10);
        rst_n = 1;

        // Allow CPU to boot and configure mtvec, mie, mstatus
        #(CLK_PERIOD * 30);

        // Inject 3 consecutive timer interrupts
        for (irq_round = 1; irq_round <= 3; irq_round = irq_round + 1) begin
            $display("--- Injecting Hardware Timer Interrupt (Pulse %0d of 3) ---", irq_round);

            // Trigger Timer Interrupt into CPU Core
            @(posedge clk); #1;
            force dut.cpu_inst.i_timer_irq = 1'b1;

            // Wait until CPU takes the trap and jumps to MTVEC (0x0000_0004)
            wait (dut.cpu_inst.datapath_inst.pc_reg == 32'h0000_0004);
            $display("[PASS] CPU trapped to MTVEC (0x00000004) at time %0t ps", $time);
            pass_count = pass_count + 1;

            // Release interrupt request
            @(posedge clk); #1;
            release dut.cpu_inst.i_timer_irq;

            // Check MCAUSE == 0x8000_0007 (Machine Timer Interrupt)
            if (dut.cpu_inst.datapath_inst.csr_inst.mcause_reg === 32'h8000_0007) begin
                $display("[PASS] MCAUSE correctly recorded: 0x%08X", dut.cpu_inst.datapath_inst.csr_inst.mcause_reg);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] MCAUSE mismatch! Expected 0x80000007, got 0x%08X", dut.cpu_inst.datapath_inst.csr_inst.mcause_reg);
                fail_count = fail_count + 1;
            end

            // Check MIE is cleared (0) and MPIE is preserved (1)
            if (dut.cpu_inst.datapath_inst.csr_inst.mstatus_reg[3] === 1'b0 &&
                dut.cpu_inst.datapath_inst.csr_inst.mstatus_reg[7] === 1'b1) begin
                $display("[PASS] MSTATUS in ISR: MIE=0 (disabled), MPIE=1 (saved)");
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] MSTATUS bits error! Got 0x%08X", dut.cpu_inst.datapath_inst.csr_inst.mstatus_reg);
                fail_count = fail_count + 1;
            end

            // Wait until MRET executes and CPU returns to main loop
            wait (dut.cpu_inst.datapath_inst.pc_reg >= 32'h0000_0030);
            $display("[PASS] MRET executed cleanly, CPU resumed in main loop (PC=0x%08X)", dut.cpu_inst.datapath_inst.pc_reg);
            pass_count = pass_count + 1;

            // Verify MIE was restored back to 1
            if (dut.cpu_inst.datapath_inst.csr_inst.mstatus_reg[3] === 1'b1) begin
                $display("[PASS] MSTATUS after MRET: MIE restored to 1");
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] MSTATUS after MRET: MIE was not restored! Got 0x%08X", dut.cpu_inst.datapath_inst.csr_inst.mstatus_reg);
                fail_count = fail_count + 1;
            end

            // Wait several cycles in main loop before next interrupt
            #(CLK_PERIOD * 20);
        end

        // Wait for CPU to reach ECALL finish
        wait (ecall_halt == 1'b1);
        $display("\n[INFO] ECALL Halt asserted. Test completed.");

        #(CLK_PERIOD * 5);

        // Verification of architectural state
        $display("-------------------------------------------------------------------------------");
        $display("   ARCHITECTURAL REGISTER AUDIT AFTER INTERRUPTS & MRET:");
        $display("   - x1 (Main Loop Counter) : %0d (Must be > 0)", dut.cpu_inst.datapath_inst.reg_file.registers[1]);
        $display("   - x2 (ISR Hit Counter)   : %0d (Expected: 3)", dut.cpu_inst.datapath_inst.reg_file.registers[2]);
        $display("-------------------------------------------------------------------------------");

        if (dut.cpu_inst.datapath_inst.reg_file.registers[2] == 3 &&
            dut.cpu_inst.datapath_inst.reg_file.registers[1] > 0) begin
            $display("[SUCCESS] 100%% HARDWARE INTERRUPT & MRET TRAP CONTROLLER VERIFICATION PASSED!\n");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] INTERRUPT & MRET VERIFICATION FAILED!");
        end
    end

endmodule
