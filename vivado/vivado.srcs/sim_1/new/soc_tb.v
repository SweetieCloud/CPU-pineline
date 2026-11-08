`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC SYSTEM INTEGRATION TESTBENCH: FULL RV32IM SOC TOP (STAGE 3)
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Hệ thống soc_top hoàn chỉnh (CPU + I-Cache +
//                              AXI Interconnect + BRAM + UART + GPIO + Timer).
//   - Layer 2 (Mock Services): Mock External Board Environment (UART Loopback
//                              & Physical Switch/Button Pin Stimulus).
//   - Layer 3 (Spy & SVA)    : Kết nối module rv32i_sva giám sát toàn bộ giao
//                              thức AXI4-Lite nội bộ, các bất biến kiến trúc và
//                              bộ đếm Spy hệ sinh thái.
//   - Layer 4 (Scoreboard)   : Các hàm expect_eq, expect_state, expect_spy.
// =============================================================================

module soc_tb;

    localparam CLK_PERIOD = 20; // 50 MHz clock

    reg        clk;
    reg        rst_n;

    // Top Pins
    wire       uart_tx;
    wire       uart_rx;
    wire [3:0] led;
    reg  [3:0] sw;
    reg  [3:0] btn;
    wire       ecall_halt;

    integer pass_count = 0;
    integer fail_count = 0;

    // Spy Counters from SVA Monitor
    wire [31:0] spy_inst_retired_cnt;
    wire [31:0] spy_icache_req_cnt;
    wire [31:0] spy_dmem_read_cnt;
    wire [31:0] spy_dmem_write_cnt;
    wire [31:0] spy_branch_mispredict_cnt;
    wire [31:0] spy_csr_write_cnt;
    wire [31:0] spy_icache_inv_cnt;
    wire [31:0] spy_div_exec_cnt;
    wire [31:0] spy_sva_error_cnt;

    // =========================================================================
    // LAYER 1: SOC TOP SYSTEM UNDER TEST (DUT)
    // =========================================================================
    soc_top #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .CLK_FREQ_HZ(50_000_000),
        .BAUD_RATE  (115_200)
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

    // =========================================================================
    // LAYER 2: MOCK EXTERNAL BOARD SERVICES (UART LOOPBACK)
    // =========================================================================
    assign uart_rx = uart_tx;

    // =========================================================================
    // LAYER 3: BIND SYSTEMVERILOG ASSERTIONS (SVA) & SPY MONITOR
    // =========================================================================
    rv32i_sva sva_soc_inst (
        .i_clk                    (clk),
        .i_rst_n                  (rst_n),
        .i_rs1_addr               (dut.cpu_inst.datapath_inst.rs1_addr_id),
        .i_rs1_data               (dut.cpu_inst.datapath_inst.rs1_data_id),
        .i_pipeline_hold          (dut.cpu_inst.datapath_inst.pipeline_hold),
        .i_pc                     (dut.cpu_inst.datapath_inst.pc_reg),
        .i_reg_write              (dut.cpu_inst.datapath_inst.ctrl_reg_write_wb),
        .i_rd_addr                (dut.cpu_inst.datapath_inst.rd_addr_wb),
        .i_inst_ret_valid         (dut.cpu_inst.datapath_inst.csr_inst.i_inst_ret_valid),
        .i_branch_mispredict      (dut.cpu_inst.datapath_inst.branch_mispredict),
        .i_csr_op                 (dut.cpu_inst.datapath_inst.ctrl_csr_op_wb),
        .i_icache_inv             (dut.cpu_inst.datapath_inst.o_icache_invalidate),
        .i_div_start              (dut.cpu_inst.datapath_inst.ctrl_is_div_ex),
        .i_div_busy               (dut.cpu_inst.datapath_inst.div_busy),
        .i_div_done               (dut.cpu_inst.datapath_inst.div_done),
        .i_dmem_req_read          (dut.cpu_inst.datapath_inst.o_dmem_req_read),
        .i_dmem_req_write         (dut.cpu_inst.datapath_inst.o_dmem_req_write),
        .i_dmem_funct3            (dut.cpu_inst.datapath_inst.o_dmem_funct3),
        .i_dmem_addr              (dut.cpu_inst.datapath_inst.o_dmem_addr),
        .i_axi_i_araddr           (dut.cpu_axi_i_araddr),
        .i_axi_i_arvalid          (dut.cpu_axi_i_arvalid),
        .i_axi_i_arready          (dut.cpu_axi_i_arready),
        .i_axi_i_rvalid           (dut.cpu_axi_i_rvalid),
        .i_axi_i_rready           (dut.cpu_axi_i_rready),
        .i_axi_d_awaddr           (dut.cpu_axi_d_awaddr),
        .i_axi_d_awvalid          (dut.cpu_axi_d_awvalid),
        .i_axi_d_awready          (dut.cpu_axi_d_awready),
        .i_axi_d_wdata            (dut.cpu_axi_d_wdata),
        .i_axi_d_wstrb            (dut.cpu_axi_d_wstrb),
        .i_axi_d_wvalid           (dut.cpu_axi_d_wvalid),
        .i_axi_d_wready           (dut.cpu_axi_d_wready),
        .i_axi_d_bvalid           (dut.cpu_axi_d_bvalid),
        .i_axi_d_bready           (dut.cpu_axi_d_bready),
        .i_axi_d_araddr           (dut.cpu_axi_d_araddr),
        .i_axi_d_arvalid          (dut.cpu_axi_d_arvalid),
        .i_axi_d_arready          (dut.cpu_axi_d_arready),
        .i_axi_d_rvalid           (dut.cpu_axi_d_rvalid),
        .i_axi_d_rready           (dut.cpu_axi_d_rready),
        .i_id_ex_flush            (dut.cpu_inst.datapath_inst.id_ex_flush),
        .i_ex_mem_flush           (dut.cpu_inst.datapath_inst.ex_mem_flush),
        .i_reg_write_ex           (dut.cpu_inst.datapath_inst.ctrl_reg_write_ex),
        .i_trap_taken             (dut.cpu_inst.datapath_inst.trap_taken),
        .i_trap_pc                (dut.cpu_inst.datapath_inst.trap_save_pc),
        .i_mepc_val               (dut.cpu_inst.datapath_inst.mepc_val),
        .spy_inst_retired_cnt     (spy_inst_retired_cnt),
        .spy_icache_req_cnt       (spy_icache_req_cnt),
        .spy_dmem_read_cnt        (spy_dmem_read_cnt),
        .spy_dmem_write_cnt       (spy_dmem_write_cnt),
        .spy_branch_mispredict_cnt(spy_branch_mispredict_cnt),
        .spy_csr_write_cnt        (spy_csr_write_cnt),
        .spy_icache_inv_cnt       (spy_icache_inv_cnt),
        .spy_div_exec_cnt         (spy_div_exec_cnt),
        .spy_sva_error_cnt        (spy_sva_error_cnt)
    );

    // =========================================================================
    // LAYER 4: SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_eq;
        input [255:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            assert (actual === expected) begin
                $display("[PASS] [EXPECT_EQ]    %-40s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_EQ]    %-40s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task expect_state;
        input [255:0] name;
        input [31:0]  actual_state;
        input [31:0]  expected_state;
        begin
            assert (actual_state === expected_state) begin
                $display("[PASS] [EXPECT_STATE] %-40s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_STATE] %-40s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task expect_spy;
        input [255:0] name;
        input integer actual_cnt;
        input integer expected_cnt;
        begin
            assert (actual_cnt === expected_cnt) begin
                $display("[PASS] [EXPECT_SPY]   %-40s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_SPY]   %-40s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // MAIN VERIFICATION SEQUENCE
    // =========================================================================
    initial begin
        $display("\n===============================================================================");
        $display("   STARTING LAYERED FULL SOC SYSTEM INTEGRATION VERIFICATION (STAGE 3)");
        $display("   CPU RV32IM + L1 I-CACHE + AXI INTERCONNECT + BRAM + UART + GPIO + TIMER");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        sw = 4'b1011; // Switches pattern: 11 (0xB)
        btn = 4'b0101;

        // Reset system
        #(CLK_PERIOD * 5);
        rst_n = 1;
        $display("[INFO] System Reset Released. CPU fetching from 0x0000_0000 via L1 I-Cache...");

        // Wait for ECALL HALT or Timeout
        fork
            begin
                wait (ecall_halt == 1'b1);
                $display("\n[INFO] ECALL HALT DETECTED! Program execution completed successfully.");
            end
            begin
                #(CLK_PERIOD * 1000);
                $display("\n[ERROR] TIMEOUT! CPU did not reach ECALL HALT within 1000 cycles.");
                fail_count = fail_count + 1;
            end
        join_any

        #(CLK_PERIOD * 5);

        // ---------------------------------------------------------------------
        // CHECKPOINT AUDIT (RETURN VALUES, ECOSYSTEM STATES & SPIES)
        // ---------------------------------------------------------------------
        $display("\n--- SYSTEM REGISTER, MEMORY, STATE & SPY AUDIT ---");
        // 1. RV32I Arithmetic: x1=5, x2=10, x3=15
        expect_eq("Reg x1 (addi 5)",    dut.cpu_inst.datapath_inst.reg_file.registers[1], 32'd5);
        expect_eq("Reg x2 (addi 10)",   dut.cpu_inst.datapath_inst.reg_file.registers[2], 32'd10);
        expect_eq("Reg x3 (add x1, x2)",dut.cpu_inst.datapath_inst.reg_file.registers[3], 32'd15);

        // 2. RV32M Hardware Multiplication: x4 = 5 * 10 = 50
        expect_eq("Reg x4 (mul x1, x2)",dut.cpu_inst.datapath_inst.reg_file.registers[4], 32'd50);

        // 3. Data Memory Access: sw x4, 64(x0) and lw x5, 64(x0)
        expect_eq("BRAM Mem[64/4] Data",dut.bram_inst.ram[16], 32'd50);
        expect_eq("Reg x5 (lw from 64)",dut.cpu_inst.datapath_inst.reg_file.registers[5], 32'd50);

        // 4. MMIO UART Access: x6=0x1000_0000, x7='H' (0x48)
        expect_eq("Reg x6 (UART Base)", dut.cpu_inst.datapath_inst.reg_file.registers[6], 32'h1000_0000);
        expect_eq("Reg x7 (Char 'H')",  dut.cpu_inst.datapath_inst.reg_file.registers[7], 32'h48);
        expect_state("UART TX Data Reg Latched 'H'", {24'd0, dut.uart_inst.tx_data_reg}, 32'h48);

        // 5. MMIO GPIO Access: Switches input read into x9, written to LEDs
        expect_eq("Reg x8 (GPIO Base)",     dut.cpu_inst.datapath_inst.reg_file.registers[8], 32'h1000_1000);
        expect_eq("Reg x9 (Switches read)", dut.cpu_inst.datapath_inst.reg_file.registers[9][3:0], 4'b1011);
        expect_eq("FPGA o_led Output Pins", {28'd0, led}, 32'h0000_000B);

        // 6. MMIO Timer Access: Read MTIME into x11
        expect_eq("Reg x10 (Timer Base)",   dut.cpu_inst.datapath_inst.reg_file.registers[10], 32'h1000_2000);
        assert (dut.cpu_inst.datapath_inst.reg_file.registers[11] > 0) begin
            $display("[PASS] [EXPECT_EQ]    Reg x11 (MTIME read > 0)                 | Actual: %0d",
                     dut.cpu_inst.datapath_inst.reg_file.registers[11]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] Reg x11 (MTIME read) == 0!");
            fail_count = fail_count + 1;
        end

        // 7. Ecosystem Spy & SVA Verification
        expect_spy("SVA Protocol & Invariant Errors == 0", spy_sva_error_cnt,  0);
        expect_spy("D-Bus Memory/MMIO Write Calls",        spy_dmem_write_cnt, 3);
        expect_spy("D-Bus Memory/MMIO Read Calls",         spy_dmem_read_cnt,  3);
        expect_spy("I-Cache Refill AXI Read Beats",        spy_icache_req_cnt, 20);

        // ---------------------------------------------------------------------
        // SUMMARY
        // ---------------------------------------------------------------------
        $display("\n===============================================================================");
        $display("   STAGE 3 SOC FULL SYSTEM INTEGRATION VERIFICATION SUMMARY");
        $display("   Total Passed : %0d", pass_count);
        $display("   Total Failed : %0d", fail_count);
        if (fail_count == 0) begin
            $display("   STATUS       : ALL CHECKS & ASSERTIONS PASSED! 100%% VERIFICATION SUCCESS");
        end else begin
            $display("   STATUS       : SOME CHECKS FAILED!");
        end
        $display("===============================================================================\n");

        #(CLK_PERIOD * 10);
        sva_soc_inst.print_sva_report;
        $finish;
    end

endmodule
