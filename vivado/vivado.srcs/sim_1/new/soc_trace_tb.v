`timescale 1ns / 1ps

// =============================================================================
// SOC MULTI-SEED INSTRUCTION-BY-INSTRUCTION RETIRE TRACE TESTBENCH
// =============================================================================
// Logs every single retired instruction (PC, destination register rd, writeback
// data, and memory store address/data) in strict architectural program order to
// "rtl_retire_trace.log" for exhaustive cycle-accurate diff against Golden Model.
// =============================================================================

module soc_trace_tb;

    localparam CLK_PERIOD = 20; // 50 MHz
    reg clk;
    reg rst_n;

    wire uart_tx;
    wire uart_rx;
    wire [3:0] led;
    reg  [3:0] sw;
    reg  [3:0] btn;
    wire ecall_halt;

    integer f_trace;
    integer retire_count;
    reg     ecall_done;

    assign uart_rx = uart_tx;

    // DUT with 100-seed regression hex
    soc_top #(
        .ADDR_WIDTH   (32),
        .DATA_WIDTH   (32),
        .CLK_FREQ_HZ  (50_000_000),
        .BAUD_RATE    (115_200),
        .BOOT_HEX_FILE("multi_seed_trace.hex")
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

    // SVA Passive Invariant Monitor Binding (25 Assertions Active)
    wire [31:0] spy_sva_error_cnt;
    rv32i_sva sva_trace_inst (
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
        .i_load_use_hazard        (dut.cpu_inst.datapath_inst.hazard.load_use_hazard),
        .i_mret_taken             (dut.cpu_inst.datapath_inst.ctrl_mret),
        .i_bht_state              (dut.cpu_inst.datapath_inst.bp_inst.bht[0]),
        .spy_sva_error_cnt        (spy_sva_error_cnt)
    );

    // Open trace log file
    initial begin
        f_trace = $fopen("rtl_retire_trace.log", "w");
        retire_count = 0;
        ecall_done = 0;
    end

    // Cycle-by-cycle retire tracer
    always @(posedge clk) begin
        if (rst_n && !dut.cpu_inst.datapath_inst.pipeline_hold && !ecall_done) begin
            // 1. WB Stage (Oldest active instruction)
            if (dut.cpu_inst.datapath_inst.ctrl_reg_write_wb && dut.cpu_inst.datapath_inst.rd_addr_wb != 5'b0) begin
                $fdisplay(f_trace, "[RETIRE] PC=0x%08X RD=x%-2d VAL=0x%08X",
                          dut.cpu_inst.datapath_inst.pc_wb,
                          dut.cpu_inst.datapath_inst.rd_addr_wb,
                          dut.cpu_inst.datapath_inst.wb_final_data);
                retire_count = retire_count + 1;
            end else if (dut.cpu_inst.datapath_inst.ctrl_ecall_halt_wb) begin
                $fdisplay(f_trace, "[RETIRE] PC=0x%08X RD=x0  VAL=0x00000000",
                          dut.cpu_inst.datapath_inst.pc_wb);
                retire_count = retire_count + 1;
                ecall_done <= 1'b1;
            end

            // 2. MEM Stage (Store instruction committing to memory)
            if (dut.cpu_inst.datapath_inst.ctrl_mem_req_write_mem) begin
                $fdisplay(f_trace, "[RETIRE] PC=0x%08X RD=x0  VAL=0x00000000 MEM_WR ADDR=0x%08X DATA=0x%08X",
                          dut.cpu_inst.datapath_inst.pc_mem,
                          dut.cpu_inst.datapath_inst.o_dmem_addr,
                          dut.cpu_inst.datapath_inst.o_dmem_wdata);
                retire_count = retire_count + 1;
            end
        end
    end

    // Watchdog Timer (2 ms = 100,000 cycles)
    initial begin
        #2_000_000;
        $fatal(1, "\n[FATAL TIMEOUT] soc_trace_tb watchdog triggered! Potential CPU stall or deadlock.");
    end

    // Main Simulation Thread
    initial begin
        $display("\n===============================================================================");
        $display("   STARTING MULTI-SEED INSTRUCTION-BY-INSTRUCTION RETIRE TRACE VERIFICATION");
        $display("   EXHAUSTIVE 100-SEED PIPELINE REGRESSION VS PYTHON GOLDEN MODEL");
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
                $display("\n[INFO] ECALL Halt asserted! Full 100-seed program executed.");
            end
            begin
                #(CLK_PERIOD * 80000);
                $fatal(1, "\n[ERROR] CPU failed to reach ECALL within 80,000 cycles.");
            end
        join_any

        #(CLK_PERIOD * 10);
        $fclose(f_trace);

        $display("-------------------------------------------------------------------------------");
        $display("   RETIRE TRACE CAPTURE COMPLETE: %0d instructions logged to rtl_retire_trace.log", retire_count);
        $display("-------------------------------------------------------------------------------");
        $finish;
    end

endmodule
