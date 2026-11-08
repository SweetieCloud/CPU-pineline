`timescale 1ns / 1ps

module csr_file_tb;

    localparam CLK_PERIOD = 20;

    reg         clk;
    reg         rst_n;
    reg  [11:0] csr_addr;
    reg  [31:0] csr_wdata;
    reg  [1:0]  csr_op;
    wire [31:0] csr_rdata;
    reg         inst_ret_valid;
    reg         timer_irq;
    reg         external_irq;
    reg         trap_taken;
    reg  [31:0] trap_pc;
    reg  [31:0] trap_cause;
    reg         mret;

    wire        trap_irq_req;
    wire [31:0] trap_target_pc;
    wire [31:0] mepc_val;
    wire [31:0] trap_irq_cause;

    csr_file #(
        .DATA_WIDTH(32)
    ) dut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .i_csr_addr      (csr_addr),
        .i_csr_wdata     (csr_wdata),
        .i_csr_op        (csr_op),
        .o_csr_rdata     (csr_rdata),
        .i_inst_ret_valid(inst_ret_valid),
        .i_timer_irq     (timer_irq),
        .i_external_irq  (external_irq),
        .i_trap_taken    (trap_taken),
        .i_trap_pc       (trap_pc),
        .i_trap_cause    (trap_cause),
        .i_mret          (mret),
        .o_trap_irq_req  (trap_irq_req),
        .o_trap_target_pc(trap_target_pc),
        .o_mepc_val      (mepc_val),
        .o_trap_irq_cause(trap_irq_cause)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    integer errors = 0;

    task check_csr;
        input [11:0] addr;
        input [31:0] expected;
        input [127:0] name;
        begin
            csr_addr = addr;
            #5;
            if (csr_rdata !== expected) begin
                $display("[FAIL] %0s (0x%03X): Expected 0x%08X, Got 0x%08X", name, addr, expected, csr_rdata);
                errors = errors + 1;
            end else begin
                $display("[PASS] %0s: 0x%08X", name, csr_rdata);
            end
        end
    endtask

    task write_csr;
        input [11:0] addr;
        input [31:0] data;
        input [1:0]  op;
        begin
            @(posedge clk);
            csr_addr       <= addr;
            csr_wdata      <= data;
            csr_op         <= op;
            inst_ret_valid <= 1'b1;
            @(posedge clk);
            csr_op         <= 2'b00;
            inst_ret_valid <= 1'b0;
            @(posedge clk);
        end
    endtask

    initial begin
        $display("\n=======================================================");
        $display("   STARTING CSR_FILE COMPREHENSIVE UNIT VERIFICATION");
        $display("=======================================================\n");

        clk = 0;
        rst_n = 0;
        csr_addr = 0;
        csr_wdata = 0;
        csr_op = 0;
        inst_ret_valid = 0;
        timer_irq = 0;
        external_irq = 0;
        trap_taken = 0;
        trap_pc = 0;
        trap_cause = 0;
        mret = 0;

        #(CLK_PERIOD * 2);
        rst_n = 1;
        #(CLK_PERIOD);

        // 1. Verify Reset & Read Values
        check_csr(12'h301, 32'h40001100, "MISA");
        check_csr(12'h300, 32'h00000000, "MSTATUS reset");
        check_csr(12'h304, 32'h00000000, "MIE reset");
        check_csr(12'h305, 32'h00000000, "MTVEC reset");
        check_csr(12'h341, 32'h00000000, "MEPC reset");
        check_csr(12'h342, 32'h00000000, "MCAUSE reset");
        check_csr(12'h343, 32'h00000000, "MTVAL reset");
        check_csr(12'h340, 32'h00000000, "MSCRATCH reset");
        check_csr(12'hFFF, 32'h00000000, "Unmapped default");

        // 2. CSRRW Writes
        write_csr(12'h305, 32'h00001000, 2'b01); // MTVEC
        write_csr(12'h340, 32'hDEADBEEF, 2'b01); // MSCRATCH
        write_csr(12'h343, 32'hBADCAFE0, 2'b01); // MTVAL
        write_csr(12'hC00, 32'h00000050, 2'b01); // MCYCLE
        write_csr(12'hC80, 32'h00000002, 2'b01); // MCYCLEH
        write_csr(12'hC02, 32'h00000020, 2'b01); // MINSTRET
        write_csr(12'hC82, 32'h00000001, 2'b01); // MINSTRETH

        check_csr(12'h305, 32'h00001000, "MTVEC after write");
        check_csr(12'h340, 32'hDEADBEEF, "MSCRATCH after write");
        check_csr(12'h343, 32'hBADCAFE0, "MTVAL after write");

        // 3. CSRRS (Bit Set) on MSTATUS (bit 3 = MIE) and MIE (bit 7 = MTIE, bit 11 = MEIE)
        write_csr(12'h300, 32'h00000008, 2'b10); // set MIE in mstatus
        write_csr(12'h304, 32'h00000880, 2'b10); // set MTIE + MEIE in mie

        check_csr(12'h300, 32'h00000008, "MSTATUS after CSRRS");
        check_csr(12'h304, 32'h00000880, "MIE after CSRRS");

        // 4. Timer Interrupt & External Interrupt Generation
        timer_irq = 1;
        #1;
        if (trap_irq_req !== 1'b1 || trap_irq_cause !== 32'h80000007) begin
            $display("[FAIL] Timer IRQ pending request failed! req=%b, cause=0x%08X", trap_irq_req, trap_irq_cause);
            errors = errors + 1;
        end else begin
            $display("[PASS] Timer IRQ asserted: req=1, cause=0x%08X, target=0x%08X", trap_irq_cause, trap_target_pc);
        end
        timer_irq = 0;

        external_irq = 1;
        #1;
        if (trap_irq_req !== 1'b1 || trap_irq_cause !== 32'h8000000B) begin
            $display("[FAIL] External IRQ pending request failed! req=%b, cause=0x%08X", trap_irq_req, trap_irq_cause);
            errors = errors + 1;
        end else begin
            $display("[PASS] External IRQ asserted: req=1, cause=0x%08X", trap_irq_cause);
        end
        external_irq = 0;

        // 5. Trap Taken Event
        @(posedge clk);
        trap_taken <= 1'b1;
        trap_pc    <= 32'h00000420;
        trap_cause <= 32'h80000007;
        @(posedge clk);
        trap_taken <= 1'b0;
        @(posedge clk);

        check_csr(12'h341, 32'h00000420, "MEPC saved");
        check_csr(12'h342, 32'h80000007, "MCAUSE saved");
        check_csr(12'h300, 32'h00000080, "MSTATUS: MIE=0, MPIE=1");

        // 6. MRET Return Event
        @(posedge clk);
        mret <= 1'b1;
        @(posedge clk);
        mret <= 1'b0;
        @(posedge clk);

        check_csr(12'h300, 32'h00000088, "MSTATUS after MRET: MIE=1 restored");

        // 7. CSRRC (Bit Clear) - Clear MPIE
        write_csr(12'h300, 32'h00000080, 2'b11); // Clear MPIE
        check_csr(12'h300, 32'h00000008, "MSTATUS after CSRRC: MPIE=0");

        $display("\n=======================================================");
        $display("   CSR_FILE VERIFICATION FINISHED: ERRORS = %0d", errors);
        $display("=======================================================\n");

        if (errors == 0) $finish;
        else $fatal(1, "CSR_FILE UNIT TEST FAILED!");
    end

endmodule
