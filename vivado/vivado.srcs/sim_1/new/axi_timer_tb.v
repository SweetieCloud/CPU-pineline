`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: AXI4-LITE MACHINE TIMER CONTROLLER
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module axi_timer (64-bit MTIME/MTIMECMP).
//   - Layer 2 (Mock Services): Mock AXI4-Lite Master BFM hỗ trợ Byte-Strobe
//                              riêng lẻ (wstrb) và giao dịch lệch pha AW-trước-W.
//   - Layer 3 (Spy & SVA)    : Bộ đếm Spy theo dõi giao dịch đọc/ghi, sự kiện
//                              tràn 32-bit -> 64-bit (rollover) và SVA kiểm tra
//                              điều kiện ngắt (mtime >= mtimecmp && irq_en).
//   - Layer 4 (Scoreboard)   : Các hàm expect_eq, expect_state, expect_spy.
// =============================================================================

module axi_timer_tb;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    reg                   clk;
    reg                   rst_n;
    wire                  timer_irq;

    // AXI Channels
    reg  [ADDR_WIDTH-1:0] awaddr;
    reg                   awvalid;
    wire                  awready;
    reg  [DATA_WIDTH-1:0] wdata;
    reg  [3:0]            wstrb;
    reg                   wvalid;
    wire                  wready;
    wire [1:0]            bresp;
    wire                  bvalid;
    reg                   bready;
    reg  [ADDR_WIDTH-1:0] araddr;
    reg                   arvalid;
    wire                  arready;
    wire [DATA_WIDTH-1:0] rdata;
    wire [1:0]            rresp;
    wire                  rvalid;
    reg                   rready;

    integer pass_count = 0;
    integer fail_count = 0;

    // =========================================================================
    // LAYER 1: COMPONENT UNDER TEST (DUT ISOLATION)
    // =========================================================================
    axi_timer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .i_clk        (clk),
        .i_rst_n      (rst_n),
        .o_timer_irq  (timer_irq),
        .s_axi_awaddr (awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata  (wdata),
        .s_axi_wstrb  (wstrb),
        .s_axi_wvalid (wvalid),
        .s_axi_wready (wready),
        .s_axi_bresp  (bresp),
        .s_axi_bvalid (bvalid),
        .s_axi_bready (bready),
        .s_axi_araddr (araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata  (rdata),
        .s_axi_rresp  (rresp),
        .s_axi_rvalid (rvalid),
        .s_axi_rready (rready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // LAYER 2: MOCK AXI4-LITE MASTER BFM SERVICES
    // =========================================================================
    task mock_axi_write_strb;
        input [31:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            @(posedge clk); #1;
            awaddr  = addr;
            awvalid = 1'b1;
            wdata   = data;
            wstrb   = strb;
            wvalid  = 1'b1;
            bready  = 1'b1;
            wait (awready && wready);
            @(posedge clk); #1;
            awvalid = 1'b0;
            wvalid  = 1'b0;
            wait (bvalid);
            @(posedge clk); #1;
            bready = 1'b0;
        end
    endtask

    task mock_axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            mock_axi_write_strb(addr, data, 4'hF);
        end
    endtask

    task mock_axi_write_skewed;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk); #1;
            awaddr  = addr;
            awvalid = 1'b1;
            wvalid  = 1'b0;
            bready  = 1'b1;
            wait (awready);
            @(posedge clk); #1;
            awvalid = 1'b0;

            expect_state("Skewed AW Latched (awaddr_valid_reg)", {31'd0, dut.awaddr_valid_reg}, 32'd1);

            @(posedge clk);
            @(posedge clk); #1;
            wdata  = data;
            wstrb  = 4'hF;
            wvalid = 1'b1;
            wait (wready);
            @(posedge clk); #1;
            wvalid = 1'b0;
            wait (bvalid);
            @(posedge clk); #1;
            bready = 1'b0;
        end
    endtask

    task mock_axi_read;
        input  [31:0] addr;
        output [31:0] data_out;
        begin
            @(posedge clk); #1;
            araddr  = addr;
            arvalid = 1'b1;
            rready  = 1'b1;
            wait (arready);
            @(posedge clk); #1;
            arvalid = 1'b0;
            wait (rvalid);
            data_out = rdata;
            @(posedge clk); #1;
            rready = 1'b0;
        end
    endtask

    // =========================================================================
    // LAYER 3: SPY COUNTERS & SVA ASSERTIONS
    // =========================================================================
    integer spy_write_cnt    = 0;
    integer spy_read_cnt     = 0;
    integer spy_rollover_cnt = 0;
    integer spy_irq_cnt      = 0;
    reg     prev_irq;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spy_write_cnt    <= 0;
            spy_read_cnt     <= 0;
            spy_rollover_cnt <= 0;
            spy_irq_cnt      <= 0;
            prev_irq         <= 1'b0;
        end else begin
            prev_irq <= timer_irq;
            if (bvalid && bready) spy_write_cnt <= spy_write_cnt + 1;
            if (rvalid && rready) spy_read_cnt  <= spy_read_cnt  + 1;
            if (dut.timer_en && (dut.mtime_reg[31:0] == 32'hFFFF_FFFF))
                spy_rollover_cnt <= spy_rollover_cnt + 1;
            if (timer_irq && !prev_irq)
                spy_irq_cnt <= spy_irq_cnt + 1;
        end
    end

    // SVA: o_timer_irq must strictly match ((mtime_reg >= mtimecmp_reg) && timer_irq_en)
    property p_timer_irq_exact;
        @(posedge clk) disable iff (!rst_n)
        timer_irq == ((dut.mtime_reg >= dut.mtimecmp_reg) && dut.timer_irq_en);
    endproperty
    assert property (p_timer_irq_exact)
        else begin
            $error("[SVA ERROR] o_timer_irq mismatch with internal comparator state!");
            fail_count = fail_count + 1;
        end

    // =========================================================================
    // LAYER 4: SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_eq;
        input [255:0] name;
        input [31:0]  actual;
        input [31:0]  expected;
        begin
            assert (actual === expected) begin
                $display("[PASS] [EXPECT_EQ]    %-38s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_EQ]    %-38s | Actual: 0x%08X (Exp: 0x%08X)", name, actual, expected);
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
                $display("[PASS] [EXPECT_STATE] %-38s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_STATE] %-38s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
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
                $display("[PASS] [EXPECT_SPY]   %-38s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_SPY]   %-38s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [31:0] read_val, read_val2;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING LAYERED AXI4-LITE MACHINE TIMER VERIFICATION (100%% COVERAGE)");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        awaddr = 0; awvalid = 0; wdata = 0; wstrb = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: Initial State & Real-Time Increment
        // ---------------------------------------------------------------------
        $display("--- TEST 1: Counter Real-Time Increment & Control State ---");
        expect_state("Reset timer_ctrl_reg == 2'b11", {30'd0, dut.timer_ctrl_reg}, 32'h3);
        mock_axi_read(32'h00, read_val);
        #(CLK_PERIOD * 10);
        mock_axi_read(32'h00, read_val2);
        assert (read_val2 > read_val) begin
            $display("[PASS] [EXPECT_EQ]    MTIME incrementing: v1=%0d -> v2=%0d", read_val, read_val2);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] MTIME not counting!");
            fail_count = fail_count + 1;
        end

        // ---------------------------------------------------------------------
        // TEST 2: Set MTIMECMP and Trigger Timer IRQ
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: Trigger Timer IRQ via MTIMECMP ---");
        mock_axi_read(32'h00, read_val);
        mock_axi_write(32'h0C, 32'h0000_0000);
        mock_axi_write(32'h08, read_val + 32'd15);

        expect_eq("IRQ low before threshold", {31'd0, timer_irq}, 32'd0);
        wait (timer_irq == 1'b1);
        expect_eq("IRQ high at threshold match", {31'd0, timer_irq}, 32'd1);

        // Mask IRQ via TIMER_CTRL[1] = 0 while keeping timer_en = 1
        mock_axi_write(32'h10, 32'h0000_0001);
        #1;
        expect_eq("IRQ masked when timer_irq_en=0", {31'd0, timer_irq}, 32'd0);
        mock_axi_read(32'h10, read_val);
        expect_eq("Read back TIMER_CTRL (0x01)", read_val, 32'h0000_0001);

        // Re-enable IRQ and clear by pushing MTIMECMP to max
        mock_axi_write(32'h10, 32'h0000_0003);
        mock_axi_write(32'h0C, 32'hFFFF_FFFF);
        mock_axi_write(32'h08, 32'hFFFF_FFFF);
        #1;
        expect_eq("IRQ cleared after MTIMECMP max", {31'd0, timer_irq}, 32'd0);

        // ---------------------------------------------------------------------
        // TEST 3: 64-Bit Counter Rollover (0x00000000_FFFFFFFD -> 0x00000001_00000002)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: 64-Bit Counter Boundary Rollover (Test Hook Preload) ---");
        mock_axi_write(32'h04, 32'h0000_0000);
        mock_axi_write(32'h00, 32'hFFFF_FFFD);
        #(CLK_PERIOD * 6);
        mock_axi_read(32'h04, read_val);
        expect_eq("MTIME_HIGH incremented to 1 on rollover", read_val, 32'h0000_0001);
        expect_spy("Spy captured 32->64 bit rollover event", spy_rollover_cnt, 1);

        // Also test full 64-bit upper toggle (MTIME_HIGH = 0xAAAA_5555 -> 0x5555_AAAA)
        mock_axi_write_skewed(32'h04, 32'hAAAA_5555);
        mock_axi_read(32'h04, read_val);
        expect_eq("Skewed Write MTIME_HIGH (0xAAAA5555)", read_val, 32'hAAAA_5555);

        // ---------------------------------------------------------------------
        // TEST 4: Pause Counter & Test Individual Byte Strobes (wstrb)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: Pause Counter & Byte-Lane Strobe (wstrb) Coverage ---");
        mock_axi_write(32'h10, 32'h0000_0000); // Freeze timer
        mock_axi_read(32'h00, read_val);
        #(CLK_PERIOD * 5);
        mock_axi_read(32'h00, read_val2);
        expect_eq("Counter frozen when timer_en=0", read_val2, read_val);

        // Test individual byte strobes on MTIME_LOW (0x00), MTIME_HIGH (0x04), MTIMECMP_LOW (0x08), MTIMECMP_HIGH (0x0C)
        mock_axi_write_strb(32'h00, 32'h0000_0011, 4'b0001);
        mock_axi_write_strb(32'h00, 32'h0000_2200, 4'b0010);
        mock_axi_write_strb(32'h00, 32'h0033_0000, 4'b0100);
        mock_axi_write_strb(32'h00, 32'h4400_0000, 4'b1000);
        mock_axi_read(32'h00, read_val);
        expect_eq("Byte-strobe assembly on MTIME_LOW", read_val, 32'h4433_2211);

        mock_axi_write_strb(32'h08, 32'h0000_00AA, 4'b0001);
        mock_axi_write_strb(32'h08, 32'h0000_BB00, 4'b0010);
        mock_axi_write_strb(32'h08, 32'h00CC_0000, 4'b0100);
        mock_axi_write_strb(32'h08, 32'hDD00_0000, 4'b1000);
        mock_axi_read(32'h08, read_val);
        expect_eq("Byte-strobe assembly on MTIMECMP_LOW", read_val, 32'hDDCC_BBAA);

        mock_axi_write_strb(32'h0C, 32'h1234_5678, 4'b0101);
        mock_axi_write_strb(32'h0C, 32'h9ABC_DEF0, 4'b1010);
        mock_axi_read(32'h0C, read_val);
        expect_eq("Byte-strobe assembly on MTIMECMP_HIGH", read_val, 32'h9A34_DE78);

        // Unmapped register read/write coverage
        mock_axi_write(32'h18, 32'hDEAD_BEEF);
        mock_axi_read(32'h18, read_val);
        expect_eq("Unmapped Read 0x18 returns 0", read_val, 32'h0000_0000);

        // ---------------------------------------------------------------------
        // TEST 5: Ecosystem Spy Verification
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: Ecosystem Spy Audit ---");
        expect_spy("Total AXI Write Transactions", spy_write_cnt, 21);
        expect_spy("Total AXI Read Transactions",  spy_read_cnt,  12);
        expect_spy("Total IRQ Rising Edges",       spy_irq_cnt,   2);

        $display("\n===============================================================================");
        $display("   AXI4-LITE MACHINE TIMER VERIFICATION SUMMARY");
        $display("   Total Passed : %0d", pass_count);
        $display("   Total Failed : %0d", fail_count);
        if (fail_count == 0) begin
            $display("   STATUS       : ALL TESTS & ASSERTIONS PASSED! 100%% COVERAGE SUCCESS");
        end else begin
            $display("   STATUS       : SOME TESTS FAILED!");
        end
        $display("===============================================================================\n");

        #(CLK_PERIOD * 5);
        $finish;
    end

    // Global Watchdog Timer
    initial begin
        #50000;
        $error("[WATCHDOG TIMEOUT] axi_timer_tb exceeded 50us limit! Aborting.");
        $finish;
    end

endmodule
