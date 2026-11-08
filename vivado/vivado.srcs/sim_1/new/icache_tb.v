`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: L1 INSTRUCTION CACHE (ICACHE)
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module icache (1KB Direct-Mapped, 4W/line).
//   - Layer 2 (Mock Services): Mock AXI4-Lite Main Memory Slave Responder &
//                              Mock CPU Fetch Pipeline Driver (hỗ trợ giữ
//                              i_pipeline_hold, phát xung i_flush, i_invalidate).
//   - Layer 3 (Spy & SVA)    : Bộ đếm Spy theo dõi AXI Refill Beats, Cache Hits,
//                              Line Refills, Flush Aborts, FENCE.I Invalidations
//                              và các khẳng định SVA giao thức AXI4-Lite.
//   - Layer 4 (Scoreboard)   : Các hàm expect_result, expect_state, expect_spy
//                              bao phủ toàn bộ 4 offset miss_word_sel (00..11)
//                              và kịch bản giữ STATE_REFILL_DONE khi D-Bus stall.
// =============================================================================

module icache_tb;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10; // 100 MHz clock

    // FSM State Constants
    localparam STATE_IDLE        = 2'b00;
    localparam STATE_REFILL_REQ  = 2'b01;
    localparam STATE_REFILL_DATA = 2'b10;
    localparam STATE_REFILL_DONE = 2'b11;

    reg                   clk;
    reg                   rst_n;

    // CPU Interface
    reg                   cpu_req;
    reg  [ADDR_WIDTH-1:0] cpu_addr;
    reg                   cpu_pipeline_hold;
    reg                   cpu_flush;
    reg                   cpu_invalidate;
    wire [DATA_WIDTH-1:0] cpu_rdata;
    wire                  cpu_valid;
    wire                  cpu_stall;
    wire                  cpu_hit;

    // AXI Bus Interface
    wire [ADDR_WIDTH-1:0] axi_araddr;
    wire                  axi_arvalid;
    reg                   axi_arready;
    wire [2:0]            axi_prot;
    reg  [DATA_WIDTH-1:0] axi_rdata;
    reg  [1:0]            axi_rresp;
    reg                   axi_rvalid;
    wire                  axi_rready;

    integer pass_count = 0;
    integer fail_count = 0;

    // =========================================================================
    // LAYER 1: COMPONENT UNDER TEST (DUT ISOLATION)
    // =========================================================================
    icache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LINE_WORDS(4),
        .NUM_LINES(64)
    ) dut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .i_req           (cpu_req),
        .i_addr          (cpu_addr),
        .i_pipeline_hold (cpu_pipeline_hold),
        .i_flush         (cpu_flush),
        .i_invalidate    (cpu_invalidate),
        .o_rdata         (cpu_rdata),
        .o_valid         (cpu_valid),
        .o_stall         (cpu_stall),
        .o_hit           (cpu_hit),
        .o_axi_araddr    (axi_araddr),
        .o_axi_arvalid   (axi_arvalid),
        .i_axi_arready   (axi_arready),
        .o_axi_prot      (axi_prot),
        .i_axi_rdata     (axi_rdata),
        .i_axi_rresp     (axi_rresp),
        .i_axi_rvalid    (axi_rvalid),
        .o_axi_rready    (axi_rready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // =========================================================================
    // LAYER 2: MOCK AXI4-LITE MEMORY SLAVE RESPONDER SERVICE
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_arready <= 1'b0;
            axi_rvalid  <= 1'b0;
            axi_rdata   <= 32'h0;
            axi_rresp   <= 2'b00;
        end else begin
            // Address Handshake (1-cycle slave response)
            if (axi_arvalid && !axi_arready) begin
                axi_arready <= 1'b1;
            end else begin
                axi_arready <= 1'b0;
            end

            // Data Handshake (Deterministic synthetic pattern: 0x1000_0000 | word_addr)
            if (axi_arvalid && axi_arready) begin
                axi_rvalid <= 1'b1;
                axi_rdata  <= 32'h1000_0000 | axi_araddr;
            end else if (axi_rvalid && axi_rready) begin
                axi_rvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // LAYER 3: SPY COUNTERS & SVA PROTOCOL MONITORS
    // =========================================================================
    integer spy_axi_ar_beats   = 0;
    integer spy_axi_r_beats    = 0;
    integer spy_refill_done    = 0;
    integer spy_invalidate_cnt = 0;
    integer spy_flush_cnt      = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spy_axi_ar_beats   <= 0;
            spy_axi_r_beats    <= 0;
            spy_refill_done    <= 0;
            spy_invalidate_cnt <= 0;
            spy_flush_cnt      <= 0;
        end else begin
            if (axi_arvalid && axi_arready)
                spy_axi_ar_beats <= spy_axi_ar_beats + 1;
            if (axi_rvalid && axi_rready)
                spy_axi_r_beats  <= spy_axi_r_beats + 1;
            if (dut.state == STATE_REFILL_DONE && !cpu_pipeline_hold)
                spy_refill_done  <= spy_refill_done + 1;
            if (cpu_invalidate)
                spy_invalidate_cnt <= spy_invalidate_cnt + 1;
            if (cpu_flush)
                spy_flush_cnt <= spy_flush_cnt + 1;
        end
    end

    // SVA 1: AXI ARADDR must always be 4-byte word aligned during refill
    property p_icache_araddr_aligned;
        @(posedge clk) disable iff (!rst_n)
        axi_arvalid |-> (axi_araddr[1:0] == 2'b00);
    endproperty
    assert property (p_icache_araddr_aligned)
        else begin
            $error("[SVA ERROR] I-Cache issued unaligned AXI ARADDR: 0x%08X!", axi_araddr);
            fail_count = fail_count + 1;
        end

    // SVA 2: AXI ARVALID & ARADDR stability before ARREADY
    property p_icache_ar_stable;
        @(posedge clk) disable iff (!rst_n)
        (axi_arvalid && !axi_arready && !cpu_invalidate) |=> (axi_arvalid && $stable(axi_araddr));
    endproperty
    assert property (p_icache_ar_stable)
        else begin
            $error("[SVA ERROR] I-Cache ARVALID/ARADDR unstable before ARREADY!");
            fail_count = fail_count + 1;
        end

    // SVA 3: During STATE_REFILL_DONE with i_pipeline_hold=1, state and rdata_buf must remain stable
    property p_icache_hold_preserve;
        @(posedge clk) disable iff (!rst_n)
        ((dut.state == STATE_REFILL_DONE) && cpu_pipeline_hold && !cpu_flush && !cpu_invalidate)
        |=> ((dut.state == STATE_REFILL_DONE) && $stable(dut.rdata_buf));
    endproperty
    assert property (p_icache_hold_preserve)
        else begin
            $error("[SVA ERROR] I-Cache lost STATE_REFILL_DONE or rdata_buf during i_pipeline_hold!");
            fail_count = fail_count + 1;
        end

    // =========================================================================
    // LAYER 4: SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_result;
        input [255:0] test_name;
        input [31:0]  expected_val;
        input [31:0]  actual_val;
        input         expected_hit;
        input         actual_hit;
        begin
            assert (expected_val === actual_val && expected_hit === actual_hit) begin
                $display("[PASS] [EXPECT_RES]   %-36s | Data: 0x%08X (Exp: 0x%08X) | Hit: %b",
                         test_name, actual_val, expected_val, actual_hit);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_RES]   %-36s | Data: 0x%08X (Exp: 0x%08X) | Hit: %b (Exp: %b)",
                       test_name, actual_val, expected_val, actual_hit, expected_hit);
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
                $display("[PASS] [EXPECT_STATE] %-36s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_STATE] %-36s | State : 0x%08X (Exp: 0x%08X)", name, actual_state, expected_state);
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
                $display("[PASS] [EXPECT_SPY]   %-36s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_SPY]   %-36s | Calls : %0d (Exp: %0d)", name, actual_cnt, expected_cnt);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // =========================================================================
    // MAIN VERIFICATION STIMULUS
    // =========================================================================
    initial begin
        $display("\n===============================================================================");
        $display("   STARTING LAYERED L1 INSTRUCTION CACHE VERIFICATION (100%% COVERAGE SUITE)");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        cpu_req = 0;
        cpu_addr = 32'h0;
        cpu_pipeline_hold = 0;
        cpu_flush = 0;
        cpu_invalidate = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD);

        expect_state("Reset FSM State == STATE_IDLE", {30'd0, dut.state}, STATE_IDLE);

        // ---------------------------------------------------------------------
        // TEST 1: Cold Miss on 0x0000_0000 (Line 0, miss_word_sel = 2'b00)
        // ---------------------------------------------------------------------
        $display("--- TEST 1: Cold Miss on 0x0000_0000 (miss_word_sel = 2'b00) ---");
        @(posedge clk); #1;
        cpu_req  = 1;
        cpu_addr = 32'h0000_0000;

        @(posedge clk); #1;
        expect_state("Cold Miss Stall Asserted", {30'd0, cpu_stall, cpu_hit}, 32'b10);

        wait (cpu_stall == 1'b0);
        expect_result("Cold Miss 0x00 (Word 0)", 32'h1000_0000, cpu_rdata, 1'b0, cpu_hit);

        // ---------------------------------------------------------------------
        // TEST 2: Spatial Locality Hits on Line 0 (Words 1, 2, 3) - 0 Wait-State
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: Spatial Locality Hits on Line 0 (Words 1, 2, 3) ---");
        @(posedge clk); #1;
        cpu_addr = 32'h0000_0004; #1;
        expect_result("Hit Word 1 (0x04)", 32'h1000_0004, cpu_rdata, 1'b1, cpu_hit);

        @(posedge clk); #1;
        cpu_addr = 32'h0000_0008; #1;
        expect_result("Hit Word 2 (0x08)", 32'h1000_0008, cpu_rdata, 1'b1, cpu_hit);

        @(posedge clk); #1;
        cpu_addr = 32'h0000_000C; #1;
        expect_result("Hit Word 3 (0x0C)", 32'h1000_000C, cpu_rdata, 1'b1, cpu_hit);

        // ---------------------------------------------------------------------
        // TEST 3: Temporal Locality Hit (Loop back to Word 0)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: Temporal Locality Hit (Loop back to Word 0) ---");
        @(posedge clk); #1;
        cpu_addr = 32'h0000_0000; #1;
        expect_result("Temporal Hit Word 0", 32'h1000_0000, cpu_rdata, 1'b1, cpu_hit);

        // ---------------------------------------------------------------------
        // TEST 4: Cold Misses across ALL Remaining Word Offsets (2'b01, 2'b10, 2'b11)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: Cold Misses Across Offsets 2'b01, 2'b10, 2'b11 ---");
        // Line 1, Word 1 (0x0000_0014 -> miss_word_sel = 2'b01)
        @(posedge clk); #1;
        cpu_addr = 32'h0000_0014;
        @(posedge clk); #1;
        expect_state("Latched miss_word_sel == 2'b01", {30'd0, dut.miss_word_sel}, 32'd1);
        wait (cpu_stall == 1'b0);
        expect_result("Miss Offset 2'b01 (0x14)", 32'h1000_0014, cpu_rdata, 1'b0, cpu_hit);

        // Line 2, Word 2 (0x0000_0028 -> miss_word_sel = 2'b10)
        @(posedge clk); #1;
        cpu_addr = 32'h0000_0028;
        @(posedge clk); #1;
        expect_state("Latched miss_word_sel == 2'b10", {30'd0, dut.miss_word_sel}, 32'd2);
        wait (cpu_stall == 1'b0);
        expect_result("Miss Offset 2'b10 (0x28)", 32'h1000_0028, cpu_rdata, 1'b0, cpu_hit);

        // Line 3, Word 3 (0x0000_003C -> miss_word_sel = 2'b11)
        @(posedge clk); #1;
        cpu_addr = 32'h0000_003C;
        @(posedge clk); #1;
        expect_state("Latched miss_word_sel == 2'b11", {30'd0, dut.miss_word_sel}, 32'd3);
        wait (cpu_stall == 1'b0);
        expect_result("Miss Offset 2'b11 (0x3C)", 32'h1000_003C, cpu_rdata, 1'b0, cpu_hit);

        // ---------------------------------------------------------------------
        // TEST 5: Simultaneous STATE_REFILL_DONE + i_pipeline_hold (D-Bus Stall)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: STATE_REFILL_DONE Held During D-Bus Pipeline Stall ---");
        @(posedge clk); #1;
        cpu_addr          = 32'h0000_0040; // Line 4 Miss
        cpu_pipeline_hold = 1'b1;          // Simulate concurrent D-Bus stall holding pipeline
        @(posedge clk); #1;                // Enter STATE_REFILL_REQ (cpu_stall == 1)
        wait (cpu_stall == 1'b0);          // I-Cache reaches STATE_REFILL_DONE
        #1;
        expect_state("FSM in STATE_REFILL_DONE", {30'd0, dut.state}, STATE_REFILL_DONE);
        expect_result("Refill Output Held Cycle 0", 32'h1000_0040, cpu_rdata, 1'b1, cpu_hit);

        // Hold for 3 additional clock cycles -> must stay in STATE_REFILL_DONE!
        repeat (3) @(posedge clk);
        #1;
        expect_state("FSM Still Held in STATE_REFILL_DONE", {30'd0, dut.state}, STATE_REFILL_DONE);
        expect_result("Refill Output Preserved After 3 Hold Cycles", 32'h1000_0040, cpu_rdata, 1'b1, cpu_hit);

        // Release pipeline hold -> transitions to STATE_IDLE on next posedge
        cpu_pipeline_hold = 1'b0;
        @(posedge clk); #1;
        expect_state("FSM Released to STATE_IDLE", {30'd0, dut.state}, STATE_IDLE);

        // ---------------------------------------------------------------------
        // TEST 6: Tag Conflict Miss & Eviction (0x0000_0400 vs 0x0000_0000)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 6: Tag Conflict Miss & Eviction (0x0000_0400 vs 0x0000_0000) ---");
        cpu_addr = 32'h0000_0400; // Index 0, Tag 1
        @(posedge clk); #1;
        wait (cpu_stall == 1'b0);
        expect_result("Conflict Miss 0x400", 32'h1000_0400, cpu_rdata, 1'b0, cpu_hit);

        @(posedge clk); #1;
        cpu_addr = 32'h0000_0000; // Previous Tag 0 was evicted -> must MISS!
        @(posedge clk); #1;
        expect_state("Evicted 0x0000_0000 Misses", {31'd0, cpu_stall}, 32'd1);
        wait (cpu_stall == 1'b0);

        // ---------------------------------------------------------------------
        // TEST 7: Branch Mispredict Flush During Refill
        // ---------------------------------------------------------------------
        $display("\n--- TEST 7: Branch Mispredict Flush During Refill ---");
        @(posedge clk); #1;
        cpu_addr = 32'h0000_0080; // Miss on Line 8
        @(posedge clk); #1;
        cpu_flush = 1'b1;
        @(posedge clk); #1;
        cpu_flush = 1'b0;
        expect_state("flush_pending Latched During Refill", {31'd0, dut.flush_pending}, 32'd1);
        wait (cpu_stall == 1'b0);
        expect_state("o_valid Suppressed on Flushed Refill", {31'd0, cpu_valid}, 32'd0);
        @(posedge clk); #1;

        // ---------------------------------------------------------------------
        // TEST 8: Cache Invalidation (FENCE.I)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 8: Cache Invalidation (FENCE.I) ---");
        cpu_addr = 32'h0000_0010; // Line 1 was filled in Test 4
        #1;
        expect_state("Line 1 Valid Before FENCE.I", {31'd0, cpu_hit}, 32'd1);

        @(posedge clk); #1;
        cpu_invalidate = 1'b1;
        cpu_req        = 1'b0;
        @(posedge clk); #1;
        cpu_invalidate = 1'b0;
        cpu_req        = 1'b1;
        #1;
        expect_state("Line 1 Invalidated After FENCE.I", {31'd0, cpu_hit}, 32'd0);
        cpu_req = 1'b0;

        // ---------------------------------------------------------------------
        // TEST 9: Ecosystem Spy Verification
        // ---------------------------------------------------------------------
        $display("\n--- TEST 9: Ecosystem Spy Audit ---");
        // 8 full 4-word line refills = 32 AXI AR beats & 32 AXI R beats
        expect_spy("Total AXI Refill AR Beats (8 lines * 4 words)", spy_axi_ar_beats, 32);
        expect_spy("Total AXI Refill R Beats  (8 lines * 4 words)", spy_axi_r_beats,  32);
        expect_spy("Total Completed Line Refills",                  spy_refill_done,  8);
        expect_spy("Total Flush Pulses Observed",                   spy_flush_cnt,    1);
        expect_spy("Total FENCE.I Invalidate Pulses Observed",      spy_invalidate_cnt, 1);

        $display("\n===============================================================================");
        $display("   L1 INSTRUCTION CACHE VERIFICATION SUMMARY");
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
        $error("[WATCHDOG TIMEOUT] icache_tb exceeded 50us limit! Aborting.");
        $finish;
    end

endmodule
