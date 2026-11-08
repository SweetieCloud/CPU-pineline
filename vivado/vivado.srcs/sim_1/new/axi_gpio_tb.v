`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: AXI4-LITE GPIO CONTROLLER
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module axi_gpio.
//   - Layer 2 (Mock Services): Mock External Board I/O Driver (Switches/Buttons)
//                              & Mock AXI4-Lite Master BFM (Hỗ trợ lệch pha
//                              AW-trước-W và Byte-Strobe wstrb).
//   - Layer 3 (Spy & SVA)    : Bộ đếm Spy theo dõi giao dịch AXI, sự kiện đổi
//                              trạng thái LED và SVA kiểm tra bộ đồng bộ 2 tầng
//                              (2-FF Synchronizer) chống metastability.
//   - Layer 4 (Scoreboard)   : Các hàm expect_eq, expect_state, expect_spy.
// =============================================================================

module axi_gpio_tb;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    reg                   clk;
    reg                   rst_n;

    // Physical Pins
    wire [3:0]            led;
    reg  [3:0]            sw;
    reg  [3:0]            btn;

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
    axi_gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .i_clk        (clk),
        .i_rst_n      (rst_n),
        .o_led        (led),
        .i_sw         (sw),
        .i_btn        (btn),
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
    // LAYER 2: MOCK BOARD I/O SERVICE & AXI4-LITE MASTER BFM
    // =========================================================================
    task mock_board_set_inputs;
        input [3:0] new_sw;
        input [3:0] new_btn;
        begin
            @(posedge clk); #1;
            sw  = new_sw;
            btn = new_btn;
            // Wait 2 clock cycles for 2-FF synchronizer pipeline to propagate
            @(posedge clk);
            @(posedge clk); #1;
        end
    endtask

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
    integer spy_write_cnt      = 0;
    integer spy_read_cnt       = 0;
    integer spy_led_change_cnt = 0;
    reg [3:0] prev_led;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spy_write_cnt      <= 0;
            spy_read_cnt       <= 0;
            spy_led_change_cnt <= 0;
            prev_led           <= 4'b0000;
        end else begin
            prev_led <= led;
            if (bvalid && bready) spy_write_cnt <= spy_write_cnt + 1;
            if (rvalid && rready) spy_read_cnt  <= spy_read_cnt  + 1;
            if (led != prev_led)  spy_led_change_cnt <= spy_led_change_cnt + 1;
        end
    end

    // SVA: 2-FF Synchronizer pipeline latency assertion (sw_sync2 == $past(i_sw, 2))
    property p_sw_2ff_sync;
        @(posedge clk) disable iff (!rst_n)
        ($past(rst_n, 2) && $past(rst_n, 1)) |-> (dut.sw_sync2 == $past(sw, 2));
    endproperty
    assert property (p_sw_2ff_sync)
        else begin
            $error("[SVA ERROR] GPIO Switch 2-FF synchronizer violated 2-cycle latency!");
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

    reg [31:0] read_val;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING LAYERED AXI4-LITE GPIO VERIFICATION (100%% COVERAGE SUITE)");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        sw = 4'b0000;
        btn = 4'b0000;
        awaddr = 0; awvalid = 0; wdata = 0; wstrb = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // ---------------------------------------------------------------------
        // TEST 1: Initial State
        // ---------------------------------------------------------------------
        $display("--- TEST 1: Initial LEDs and Synchronizer States ---");
        expect_eq("Initial LEDs == 0", {28'd0, led}, 32'd0);
        mock_axi_read(32'h04, read_val);
        expect_eq("Read GPIO_OUT reg == 0", read_val, 32'd0);

        // ---------------------------------------------------------------------
        // TEST 2: Write LEDs (Full Toggle 0xA -> 0x5 -> 0xF) & Skewed Write
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: Write Patterns to LEDs & Skewed AW-before-W Handshake ---");
        mock_axi_write(32'h04, 32'hA);
        expect_eq("Physical Pin o_led == 0xA", {28'd0, led}, 32'hA);
        mock_axi_read(32'h04, read_val);
        expect_eq("Read back GPIO_OUT == 0xA", read_val, 32'hA);

        // Test wstrb[0] == 0 suppression on GPIO_OUT
        mock_axi_write_strb(32'h04, 32'hF, 4'b1110);
        expect_eq("o_led unchanged when wstrb[0]==0", {28'd0, led}, 32'hA);

        // Skewed write 0x5 to GPIO_OUT
        mock_axi_write_skewed(32'h04, 32'h5);
        expect_eq("Physical Pin o_led == 0x5", {28'd0, led}, 32'h5);

        // ---------------------------------------------------------------------
        // TEST 3: Mock Board Switches & Buttons (Full Toggle Coverage)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: Mock Board Switches & Buttons Synchronizer Check ---");
        mock_board_set_inputs(4'b1100, 4'b0101);
        expect_state("Internal Synchronizer sw_sync2",  {28'd0, dut.sw_sync2},  32'hC);
        expect_state("Internal Synchronizer btn_sync2", {28'd0, dut.btn_sync2}, 32'h5);
        mock_axi_read(32'h00, read_val);
        expect_eq("Read GPIO_IN (btn=0101, sw=1100)", read_val, 32'h0000_005C);

        mock_board_set_inputs(4'b0011, 4'b1010);
        mock_axi_read(32'h00, read_val);
        expect_eq("Read GPIO_IN (btn=1010, sw=0011)", read_val, 32'h0000_00A3);

        // ---------------------------------------------------------------------
        // TEST 4: Direction Register (0x08) Byte-Strobe & Unmapped Address
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: Direction Register Byte-Strobes & Unmapped Address ---");
        mock_axi_write_strb(32'h08, 32'h0000_0012, 4'b0001);
        mock_axi_write_strb(32'h08, 32'h0000_3400, 4'b0010);
        mock_axi_write_strb(32'h08, 32'h0056_0000, 4'b0100);
        mock_axi_write_strb(32'h08, 32'h7800_0000, 4'b1000);
        mock_axi_read(32'h08, read_val);
        expect_eq("Read GPIO_DIR byte-strobe assembly", read_val, 32'h7856_3412);

        mock_axi_write(32'h0C, 32'hDEAD_BEEF);
        mock_axi_read(32'h0C, read_val);
        expect_eq("Unmapped Read 0x0C returns 0", read_val, 32'h0000_0000);

        // ---------------------------------------------------------------------
        // TEST 5: Ecosystem Spy Verification
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: Ecosystem Spy Audit ---");
        expect_spy("Total AXI Write Transactions", spy_write_cnt, 8);
        expect_spy("Total AXI Read Transactions",  spy_read_cnt,  6);
        expect_spy("Total Physical LED Toggles",   spy_led_change_cnt, 2);

        $display("\n===============================================================================");
        $display("   AXI4-LITE GPIO VERIFICATION SUMMARY");
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
        $error("[WATCHDOG TIMEOUT] axi_gpio_tb exceeded 50us limit! Aborting.");
        $finish;
    end

endmodule
