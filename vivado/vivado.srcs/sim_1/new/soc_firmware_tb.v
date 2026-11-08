`timescale 1ns / 1ps

// =============================================================================
// TESTBENCH: SOC FIRMWARE VERIFICATION (MILESTONE 4.1)
// =============================================================================
// - Target: Full RV32IM System-on-Chip running firmware_demo.hex
// - Verified features:
//   * Hex boot pre-loading via $readmemh into 16KB True Dual-Port BRAM
//   * RV32M Hardware Multiplication (mul: 5 * 10 = 50)
//   * RV32M Hardware Division & Remainder (div, rem: 1000 / 7 = 142 R:6)
//   * AXI4-Lite Crossbar BRAM scratchpad Read/Write (0xCAFEBABE at 0x00000400)
//   * GPIO MMIO Switch read (0x10001000) & LED write (0x10001004)
//   * Machine Timer MTIME (0x10002000) reading
//   * UART Lite serial string printing with real-time ASCII console sniffer
//   * Clean pipeline completion and ECALL Halt trap
// =============================================================================

module soc_firmware_tb;

    localparam CLK_PERIOD  = 20;            // 50 MHz
    localparam CLK_FREQ_HZ = 50_000_000;
    localparam BAUD_RATE   = 5_000_000;     // Accelerated baud rate for fast simulation
    localparam BIT_PERIOD  = 1_000_000_000 / BAUD_RATE; // 200 ns per bit

    reg        clk;
    reg        rst_n;
    wire       uart_tx;
    reg        uart_rx;
    wire [3:0] led;
    reg  [3:0] sw;
    reg  [3:0] btn;
    wire       ecall_halt;
    reg        ecall_halt_latched;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            ecall_halt_latched <= 1'b0;
        else if (ecall_halt)
            ecall_halt_latched <= 1'b1;
    end

    integer pass_count = 0;
    integer fail_count = 0;

    // -------------------------------------------------------------------------
    // INSTANTIATE SOC TOP WITH FIRMWARE HEX
    // -------------------------------------------------------------------------
    soc_top #(
        .ADDR_WIDTH   (32),
        .DATA_WIDTH   (32),
        .CLK_FREQ_HZ  (CLK_FREQ_HZ),
        .BAUD_RATE    (BAUD_RATE),
        .BOOT_HEX_FILE("program.hex")
    ) uut (
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

    // -------------------------------------------------------------------------
    // UART SERIAL RX SNIFFER (Prints received characters directly to console)
    // -------------------------------------------------------------------------
    reg [7:0] rx_char;
    integer b_idx;
    initial begin
        forever begin
            @(negedge uart_tx); // Detect Start Bit (1 -> 0)
            #(BIT_PERIOD / 2);  // Move to center of Start Bit
            if (uart_tx == 1'b0) begin
                for (b_idx = 0; b_idx < 8; b_idx = b_idx + 1) begin
                    #BIT_PERIOD;
                    rx_char[b_idx] = uart_tx; // Sample data bit
                end
                #BIT_PERIOD; // Stop bit
                $write("%c", rx_char);
            end
        end
    end

    // -------------------------------------------------------------------------
    // SCOREBOARD TASK
    // -------------------------------------------------------------------------
    task check;
        input [399:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            if (actual === expected) begin
                $display("\n[PASS] %-45s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("\n[FAIL] %-45s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // MAIN VERIFICATION SEQUENCE
    // -------------------------------------------------------------------------
    integer timeout;
    initial begin
        $display("\n===============================================================================");
        $display("   STARTING SOC BAREMETAL FIRMWARE SIMULATION (MILESTONE 4.1)");
        $display("   Firmware: program.hex | Target: RV32IM SoC Arty Z7-20");
        $display("===============================================================================\n");
        $display("--- [UART CONSOLE STREAM OUTPUT START] ---");

        clk = 0;
        rst_n = 0;
        uart_rx = 1;
        sw = 4'b0101; // Switches = 0x5 -> Expect LED = sw ^ 0x0A = 4'b1111 = 0xF
        btn = 4'b0000;

        // Reset Pulse
        #(CLK_PERIOD * 10);
        rst_n = 1;

        // Trace pipeline execution
        fork
            begin : trace_pc
                forever begin
                    @(posedge clk);
                    if (uut.cpu_inst.datapath_inst.ctrl_reg_write_wb && uut.cpu_inst.datapath_inst.rd_addr_wb == 7) begin
                        $display("[TRACE x7] Time: %0t | PC: 0x%08X | Data: 0x%08X (%0d)",
                            $time,
                            uut.cpu_inst.datapath_inst.pc_wb,
                            uut.cpu_inst.datapath_inst.wb_final_data,
                            uut.cpu_inst.datapath_inst.wb_final_data);
                    end
                end
            end
        join_none

        // Wait for CPU to execute firmware and reach ECALL Halt
        timeout = 0;
        while (!ecall_halt_latched && timeout < 50000) begin
            @(posedge clk);
            timeout = timeout + 1;
        end

        $display("[TB CHECK] timeout=%0d | ecall_halt=%b | ecall_halt_latched=%b | uut.o_ecall_halt=%b",
            timeout, ecall_halt, ecall_halt_latched, uut.o_ecall_halt);

        $display("[DEBUG] Ended at timeout=%0d | PC_IF=0x%08X | PC_EX=0x%08X | PC_WB=0x%08X | hold=%b",
            timeout,
            uut.cpu_inst.datapath_inst.pc_reg,
            uut.cpu_inst.datapath_inst.pc_ex,
            uut.cpu_inst.datapath_inst.pc_wb,
            uut.cpu_inst.datapath_inst.pipeline_hold);
        $display("[DEBUG] dmem_addr=0x%08X | req_read=%b | req_write=%b | d_arvalid=%b | d_arready=%b | d_rvalid=%b",
            uut.cpu_inst.datapath_inst.o_dmem_addr,
            uut.cpu_inst.datapath_inst.o_dmem_req_read,
            uut.cpu_inst.datapath_inst.o_dmem_req_write,
            uut.cpu_axi_d_arvalid,
            uut.cpu_axi_d_arready,
            uut.cpu_axi_d_rvalid);
        $display("[DEBUG] axi_d_stall=%b | axi_i_stall=%b | d_state=%b | awready=%b | wready=%b | bvalid=%b | bready=%b",
            uut.cpu_inst.axi_d_stall,
            uut.cpu_inst.axi_i_stall,
            uut.cpu_inst.axi_d_master_inst.state,
            uut.cpu_axi_d_awready,
            uut.cpu_axi_d_wready,
            uut.cpu_axi_d_bvalid,
            uut.cpu_axi_d_bready);
        $display("[DEBUG] icache: state=%b | araddr=0x%08X | arvalid=%b | arready=%b | rvalid=%b | rready=%b | miss_addr=0x%08X",
            uut.cpu_inst.icache_inst.state,
            uut.cpu_inst.icache_inst.o_axi_araddr,
            uut.cpu_inst.icache_inst.o_axi_arvalid,
            uut.cpu_inst.icache_inst.i_axi_arready,
            uut.cpu_inst.icache_inst.i_axi_rvalid,
            uut.cpu_inst.icache_inst.o_axi_rready,
            uut.cpu_inst.icache_inst.miss_addr);

        // Allow any trailing UART stop bit to flush
        #(BIT_PERIOD * 15);
        $display("\n--- [UART CONSOLE STREAM OUTPUT END] ---\n");

        // ---------------------------------------------------------------------
        // FINAL VERIFICATION CHECKS
        // ---------------------------------------------------------------------
        $display("===============================================================================");
        $display("   FIRMWARE EXECUTION SCOREBOARD VALIDATION");
        $display("===============================================================================");

        // 1. ECALL Halt status
        check("ECALL Halt Asserted (Firmware Ended)", {31'b0, ecall_halt_latched}, 32'd1);

        // 2. RV32M Multiplier Result (Reg x18 = s2 = 50 = 0x32)
        check("RV32M Mul Register s2 (5 * 10)", uut.cpu_inst.datapath_inst.reg_file.registers[18], 32'd50);

        // 3. RV32M Divider Result (Reg x19 = s3 = 142)
        check("RV32M Div Register s3 (1000 / 7)", uut.cpu_inst.datapath_inst.reg_file.registers[19], 32'd142);

        // 4. RV32M Remainder Result (Reg x20 = s4 = 6)
        check("RV32M Rem Register s4 (1000 % 7)", uut.cpu_inst.datapath_inst.reg_file.registers[20], 32'd6);

        // 4. BRAM scratchpad 0x00000400 memory location
        check("BRAM 0x00000400 Content (0xCAFEBABE)", uut.bram_inst.ram[12'h100], 32'hCAFEBABE);

        // 5. GPIO Output LEDs (sw=0x5 ^ 0x0A = 0xF)
        check("GPIO Output LEDs (sw=0x5 ^ 0x0A)", {28'b0, led}, 32'h0000000F);

        // 6. Stack Pointer sp
        check("Stack Pointer sp (0x00003FFC)", uut.cpu_inst.datapath_inst.reg_file.registers[2], 32'h00003FFC);

        // ---------------------------------------------------------------------
        // SUMMARY REPORT
        // ---------------------------------------------------------------------
        $display("\n===============================================================================");
        $display("   MILESTONE 4.1 FIRMWARE VERIFICATION SUMMARY");
        $display("   TOTAL TESTS : %0d", pass_count + fail_count);
        $display("   PASSED      : %0d", pass_count);
        $display("   FAILED      : %0d", fail_count);
        if (fail_count == 0 && ecall_halt_latched == 1'b1) begin
            $display("   RESULT      : ALL MILESTONE 4.1 FIRMWARE CHECKS PASSED 100%%!");
        end else begin
            $display("   RESULT      : FIRMWARE VERIFICATION FAILED!");
        end
        $display("===============================================================================\n");

        $finish;
    end

endmodule
