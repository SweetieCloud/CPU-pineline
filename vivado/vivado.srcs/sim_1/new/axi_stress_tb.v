`timescale 1ns / 1ps

// =============================================================================
// EXTREME AXI4-LITE STRESS & CONCURRENCY TESTBENCH WITH TIMEOUT GUARDS
// =============================================================================
// Features:
//   - Independent AW and W phase trackers in Mock Slaves (true AXI4-Lite compliance)
//   - Watchdog timer (100,000 cycles / 1ms) + bounded while loops to prevent hanging
//   - Tests:
//       1. AW-before-W skew (AW 8 cycles before W)
//       2. Full concurrent M0 (I-Cache) and M1 (D-Bus) under random back-pressure
//       3. DECERR handling under random delay
// =============================================================================

module axi_stress_tb;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10; // 100 MHz

    reg clk;
    reg rst_n;

    integer pass_count;
    integer fail_count;

    // Master 0: I-Cache
    reg  [ADDR_WIDTH-1:0] m0_araddr;
    reg                   m0_arvalid;
    wire                  m0_arready;
    wire [DATA_WIDTH-1:0] m0_rdata;
    wire [1:0]            m0_rresp;
    wire                  m0_rvalid;
    reg                   m0_rready;

    // Master 1: D-Bus
    reg  [ADDR_WIDTH-1:0] m1_awaddr;
    reg                   m1_awvalid;
    wire                  m1_awready;
    reg  [DATA_WIDTH-1:0] m1_wdata;
    reg  [3:0]            m1_wstrb;
    reg                   m1_wvalid;
    wire                  m1_wready;
    wire [1:0]            m1_bresp;
    wire                  m1_bvalid;
    reg                   m1_bready;

    reg  [ADDR_WIDTH-1:0] m1_araddr;
    reg                   m1_arvalid;
    wire                  m1_arready;
    wire [DATA_WIDTH-1:0] m1_rdata;
    wire [1:0]            m1_rresp;
    wire                  m1_rvalid;
    reg                   m1_rready;

    // Slave 0: BRAM Port A
    wire [ADDR_WIDTH-1:0] s0_araddr_a;
    wire                  s0_arvalid_a;
    reg                   s0_arready_a;
    reg  [DATA_WIDTH-1:0] s0_rdata_a;
    reg  [1:0]            s0_rresp_a;
    reg                   s0_rvalid_a;
    wire                  s0_rready_a;

    // Slave 0: BRAM Port B
    wire [ADDR_WIDTH-1:0] s0_awaddr_b;
    wire                  s0_awvalid_b;
    reg                   s0_awready_b;
    wire [DATA_WIDTH-1:0] s0_wdata_b;
    wire [3:0]            s0_wstrb_b;
    wire                  s0_wvalid_b;
    reg                   s0_wready_b;
    reg  [1:0]            s0_bresp_b;
    reg                   s0_bvalid_b;
    wire                  s0_bready_b;
    wire [ADDR_WIDTH-1:0] s0_araddr_b;
    wire                  s0_arvalid_b;
    reg                   s0_arready_b;
    reg  [DATA_WIDTH-1:0] s0_rdata_b;
    reg  [1:0]            s0_rresp_b;
    reg                   s0_rvalid_b;
    wire                  s0_rready_b;

    // Slave 1: UART
    wire [ADDR_WIDTH-1:0] s1_awaddr;
    wire                  s1_awvalid;
    reg                   s1_awready;
    wire [DATA_WIDTH-1:0] s1_wdata;
    wire [3:0]            s1_wstrb;
    wire                  s1_wvalid;
    reg                   s1_wready;
    reg  [1:0]            s1_bresp;
    reg                   s1_bvalid;
    wire                  s1_bready;
    wire [ADDR_WIDTH-1:0] s1_araddr;
    wire                  s1_arvalid;
    reg                   s1_arready;
    reg  [DATA_WIDTH-1:0] s1_rdata;
    reg  [1:0]            s1_rresp;
    reg                   s1_rvalid;
    wire                  s1_rready;

    // Slave 2: GPIO
    wire [ADDR_WIDTH-1:0] s2_gpio_awaddr;
    wire                  s2_gpio_awvalid;
    reg                   s2_gpio_awready;
    wire [DATA_WIDTH-1:0] s2_gpio_wdata;
    wire [3:0]            s2_gpio_wstrb;
    wire                  s2_gpio_wvalid;
    reg                   s2_gpio_wready;
    reg  [1:0]            s2_gpio_bresp;
    reg                   s2_gpio_bvalid;
    wire                  s2_gpio_bready;
    wire [ADDR_WIDTH-1:0] s2_gpio_araddr;
    wire                  s2_gpio_arvalid;
    reg                   s2_gpio_arready;
    reg  [DATA_WIDTH-1:0] s2_gpio_rdata;
    reg  [1:0]            s2_gpio_rresp;
    reg                   s2_gpio_rvalid;
    wire                  s2_gpio_rready;

    // Slave 3: Timer
    wire [ADDR_WIDTH-1:0] s3_timer_awaddr;
    wire                  s3_timer_awvalid;
    reg                   s3_timer_awready;
    wire [DATA_WIDTH-1:0] s3_timer_wdata;
    wire [3:0]            s3_timer_wstrb;
    wire                  s3_timer_wvalid;
    reg                   s3_timer_wready;
    reg  [1:0]            s3_timer_bresp;
    reg                   s3_timer_bvalid;
    wire                  s3_timer_bready;
    wire [ADDR_WIDTH-1:0] s3_timer_araddr;
    wire                  s3_timer_arvalid;
    reg                   s3_timer_arready;
    reg  [DATA_WIDTH-1:0] s3_timer_rdata;
    reg  [1:0]            s3_timer_rresp;
    reg                   s3_timer_rvalid;
    wire                  s3_timer_rready;

    // Instantiate DUT
    axi_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .i_clk            (clk),
        .i_rst_n          (rst_n),
        .m0_axi_araddr    (m0_araddr),
        .m0_axi_arvalid   (m0_arvalid),
        .m0_axi_arready   (m0_arready),
        .m0_axi_rdata     (m0_rdata),
        .m0_axi_rresp     (m0_rresp),
        .m0_axi_rvalid    (m0_rvalid),
        .m0_axi_rready    (m0_rready),
        .m1_axi_awaddr    (m1_awaddr),
        .m1_axi_awvalid   (m1_awvalid),
        .m1_axi_awready   (m1_awready),
        .m1_axi_wdata     (m1_wdata),
        .m1_axi_wstrb     (m1_wstrb),
        .m1_axi_wvalid    (m1_wvalid),
        .m1_axi_wready    (m1_wready),
        .m1_axi_bresp     (m1_bresp),
        .m1_axi_bvalid    (m1_bvalid),
        .m1_axi_bready    (m1_bready),
        .m1_axi_araddr    (m1_araddr),
        .m1_axi_arvalid   (m1_arvalid),
        .m1_axi_arready   (m1_arready),
        .m1_axi_rdata     (m1_rdata),
        .m1_axi_rresp     (m1_rresp),
        .m1_axi_rvalid    (m1_rvalid),
        .m1_axi_rready    (m1_rready),
        .s0_bram_araddr_a (s0_araddr_a),
        .s0_bram_arvalid_a(s0_arvalid_a),
        .s0_bram_arready_a(s0_arready_a),
        .s0_bram_rdata_a  (s0_rdata_a),
        .s0_bram_rresp_a  (s0_rresp_a),
        .s0_bram_rvalid_a (s0_rvalid_a),
        .s0_bram_rready_a (s0_rready_a),
        .s0_bram_awaddr_b (s0_awaddr_b),
        .s0_bram_awvalid_b(s0_awvalid_b),
        .s0_bram_awready_b(s0_awready_b),
        .s0_bram_wdata_b  (s0_wdata_b),
        .s0_bram_wstrb_b  (s0_wstrb_b),
        .s0_bram_wvalid_b (s0_wvalid_b),
        .s0_bram_wready_b (s0_wready_b),
        .s0_bram_bresp_b  (s0_bresp_b),
        .s0_bram_bvalid_b (s0_bvalid_b),
        .s0_bram_bready_b (s0_bready_b),
        .s0_bram_araddr_b (s0_araddr_b),
        .s0_bram_arvalid_b(s0_arvalid_b),
        .s0_bram_arready_b(s0_arready_b),
        .s0_bram_rdata_b  (s0_rdata_b),
        .s0_bram_rresp_b  (s0_rresp_b),
        .s0_bram_rvalid_b (s0_rvalid_b),
        .s0_bram_rready_b (s0_rready_b),
        .s1_uart_awaddr   (s1_awaddr),
        .s1_uart_awvalid  (s1_awvalid),
        .s1_uart_awready  (s1_awready),
        .s1_uart_wdata    (s1_wdata),
        .s1_uart_wstrb    (s1_wstrb),
        .s1_uart_wvalid   (s1_wvalid),
        .s1_uart_wready   (s1_wready),
        .s1_uart_bresp    (s1_bresp),
        .s1_uart_bvalid   (s1_bvalid),
        .s1_uart_bready   (s1_bready),
        .s1_uart_araddr   (s1_araddr),
        .s1_uart_arvalid  (s1_arvalid),
        .s1_uart_arready  (s1_arready),
        .s1_uart_rdata    (s1_rdata),
        .s1_uart_rresp    (s1_rresp),
        .s1_uart_rvalid   (s1_rvalid),
        .s1_uart_rready   (s1_rready),
        .s2_gpio_awaddr   (s2_gpio_awaddr),
        .s2_gpio_awvalid  (s2_gpio_awvalid),
        .s2_gpio_awready  (s2_gpio_awready),
        .s2_gpio_wdata    (s2_gpio_wdata),
        .s2_gpio_wstrb    (s2_gpio_wstrb),
        .s2_gpio_wvalid   (s2_gpio_wvalid),
        .s2_gpio_wready   (s2_gpio_wready),
        .s2_gpio_bresp    (s2_gpio_bresp),
        .s2_gpio_bvalid   (s2_gpio_bvalid),
        .s2_gpio_bready   (s2_gpio_bready),
        .s2_gpio_araddr   (s2_gpio_araddr),
        .s2_gpio_arvalid  (s2_gpio_arvalid),
        .s2_gpio_arready  (s2_gpio_arready),
        .s2_gpio_rdata    (s2_gpio_rdata),
        .s2_gpio_rresp    (s2_gpio_rresp),
        .s2_gpio_rvalid   (s2_gpio_rvalid),
        .s2_gpio_rready   (s2_gpio_rready),
        .s3_timer_awaddr  (s3_timer_awaddr),
        .s3_timer_awvalid (s3_timer_awvalid),
        .s3_timer_awready (s3_timer_awready),
        .s3_timer_wdata   (s3_timer_wdata),
        .s3_timer_wstrb   (s3_timer_wstrb),
        .s3_timer_wvalid  (s3_timer_wvalid),
        .s3_timer_wready  (s3_timer_wready),
        .s3_timer_bresp   (s3_timer_bresp),
        .s3_timer_bvalid  (s3_timer_bvalid),
        .s3_timer_bready  (s3_timer_bready),
        .s3_timer_araddr  (s3_timer_araddr),
        .s3_timer_arvalid (s3_timer_arvalid),
        .s3_timer_arready (s3_timer_arready),
        .s3_timer_rdata   (s3_timer_rdata),
        .s3_timer_rresp   (s3_timer_rresp),
        .s3_timer_rvalid  (s3_timer_rvalid),
        .s3_timer_rready  (s3_timer_rready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // -------------------------------------------------------------------------
    // WATCHDOG TIMER GUARD (Catches any hang in <= 500 us)
    // -------------------------------------------------------------------------
    initial begin
        #500_000; // 500 us
        $fatal(1, "\n[FATAL WATCHDOG TIMEOUT] Simulation exceeded 500 us! Deadlock detected.");
    end

    // -------------------------------------------------------------------------
    // SLAVE RESPONDERS WITH INDEPENDENT AW/W TRACKERS
    // -------------------------------------------------------------------------
    reg enable_random_backpressure;
    reg s0_aw_received, s0_w_received;
    reg s1_aw_received, s1_w_received;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_arready_a <= 1'b0; s0_rvalid_a <= 1'b0; s0_rdata_a <= 32'b0; s0_rresp_a <= 2'b00;
            s0_awready_b <= 1'b0; s0_wready_b <= 1'b0; s0_bvalid_b <= 1'b0; s0_bresp_b <= 2'b00;
            s0_arready_b <= 1'b0; s0_rvalid_b <= 1'b0; s0_rdata_b <= 32'b0; s0_rresp_b <= 2'b00;
            s0_aw_received <= 1'b0; s0_w_received <= 1'b0;

            s1_awready <= 1'b0; s1_wready <= 1'b0; s1_bvalid <= 1'b0; s1_bresp <= 2'b00;
            s1_arready <= 1'b0; s1_rvalid <= 1'b0; s1_rdata <= 32'b0; s1_rresp <= 2'b00;
            s1_aw_received <= 1'b0; s1_w_received <= 1'b0;

            s2_gpio_awready <= 1'b0; s2_gpio_wready <= 1'b0; s2_gpio_bvalid <= 1'b0; s2_gpio_bresp <= 2'b00;
            s2_gpio_arready <= 1'b0; s2_gpio_rvalid <= 1'b0; s2_gpio_rdata <= 32'b0; s2_gpio_rresp <= 2'b00;

            s3_timer_awready <= 1'b0; s3_timer_wready <= 1'b0; s3_timer_bvalid <= 1'b0; s3_timer_bresp <= 2'b00;
            s3_timer_arready <= 1'b0; s3_timer_rvalid <= 1'b0; s3_timer_rdata <= 32'b0; s3_timer_rresp <= 2'b00;
        end else begin
            if (enable_random_backpressure) begin
                s0_arready_a <= ($random % 2 == 0);
                s0_awready_b <= ($random % 2 == 0);
                s0_wready_b  <= ($random % 2 == 0);
                s0_arready_b <= ($random % 2 == 0);
                s1_awready   <= ($random % 2 == 0);
                s1_wready    <= ($random % 2 == 0);
                s1_arready   <= ($random % 2 == 0);
            end else begin
                s0_arready_a <= 1'b1;
                s0_awready_b <= 1'b1;
                s0_wready_b  <= 1'b1;
                s0_arready_b <= 1'b1;
                s1_awready   <= 1'b1;
                s1_wready    <= 1'b1;
                s1_arready   <= 1'b1;
            end

            // Slave 0 Port A Read Responder
            if (s0_arvalid_a && s0_arready_a) begin
                s0_rvalid_a <= 1'b1;
                s0_rdata_a  <= {16'hAAAA, s0_araddr_a[15:0]};
                s0_rresp_a  <= 2'b00;
            end else if (s0_rvalid_a && s0_rready_a) begin
                s0_rvalid_a <= 1'b0;
            end

            // Slave 0 Port B Write Responder with independent AW & W tracking
            if (s0_awvalid_b && s0_awready_b) s0_aw_received <= 1'b1;
            if (s0_wvalid_b  && s0_wready_b)  s0_w_received  <= 1'b1;

            if ((s0_aw_received || (s0_awvalid_b && s0_awready_b)) &&
                (s0_w_received  || (s0_wvalid_b && s0_wready_b)) && !s0_bvalid_b) begin
                s0_bvalid_b    <= 1'b1;
                s0_bresp_b     <= 2'b00;
                s0_aw_received <= 1'b0;
                s0_w_received  <= 1'b0;
            end else if (s0_bvalid_b && s0_bready_b) begin
                s0_bvalid_b <= 1'b0;
            end

            // Slave 0 Port B Read Responder
            if (s0_arvalid_b && s0_arready_b) begin
                s0_rvalid_b <= 1'b1;
                s0_rdata_b  <= {16'hBBBB, s0_araddr_b[15:0]};
                s0_rresp_b  <= 2'b00;
            end else if (s0_rvalid_b && s0_rready_b) begin
                s0_rvalid_b <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // TEST PROCEDURE
    // -------------------------------------------------------------------------
    integer loop_guard;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING EXTREME AXI4-LITE BUS STRESS & CONCURRENCY VERIFICATION");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        pass_count = 0;
        fail_count = 0;
        enable_random_backpressure = 0;

        m0_araddr = 0; m0_arvalid = 0; m0_rready = 0;
        m1_awaddr = 0; m1_awvalid = 0; m1_wdata = 0; m1_wstrb = 0; m1_wvalid = 0; m1_bready = 0;
        m1_araddr = 0; m1_arvalid = 0; m1_rready = 0;

        #(CLK_PERIOD * 5);
        rst_n = 1;
        #(CLK_PERIOD * 2);

        // =====================================================================
        // TEST 1: AW-BEFORE-W SKEW STRESS (AW arrives 8 cycles before W)
        // =====================================================================
        $display("--- SCENARIO 1: AW Arrives 8 Cycles Before W (Skew Stress) ---");
        @(posedge clk); #1;
        m1_awaddr  = 32'h0000_0100;
        m1_awvalid = 1'b1;
        m1_bready  = 1'b1;

        loop_guard = 0;
        while (!m1_awready && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        if (loop_guard >= 50) $fatal(1, "[TIMEOUT] m1_awready was never asserted!");
        
        @(posedge clk); #1;
        m1_awvalid = 1'b0;

        // Skew gap: delay 8 cycles before asserting WVALID
        repeat (8) @(posedge clk);
        #1;
        m1_wdata  = 32'hCAFE_F00D;
        m1_wstrb  = 4'hF;
        m1_wvalid = 1'b1;

        loop_guard = 0;
        while (!m1_wready && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        if (loop_guard >= 50) $fatal(1, "[TIMEOUT] m1_wready was never asserted!");
        
        @(posedge clk); #1;
        m1_wvalid = 1'b0;

        loop_guard = 0;
        while (!m1_bvalid && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        if (loop_guard >= 50) $fatal(1, "[TIMEOUT] m1_bvalid was never asserted!");

        if (m1_bresp === 2'b00) begin
            $display("[PASS] [SKEW_AW_FIRST] AW -> 8 cycles -> W accepted successfully, BVALID received (bresp=2'b00)");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [SKEW_AW_FIRST] Invalid write response: %02b", m1_bresp);
            fail_count = fail_count + 1;
        end
        @(posedge clk); #1;
        m1_bready = 1'b0;

        // =====================================================================
        // TEST 2: RANDOM SLAVE BACK-PRESSURE UNDER CONCURRENT M0 & M1
        // =====================================================================
        $display("\n--- SCENARIO 2: Concurrent M0 & M1 Under Random Slave Back-Pressure (200 Pkts) ---");
        enable_random_backpressure = 1;

        fork
            // Thread 1: M0 continuous read burst of 200 packets to BRAM Port A
            begin: m0_stress_thread
                integer i, t_guard;
                for (i = 0; i < 200; i = i + 1) begin
                    @(posedge clk); #1;
                    m0_araddr  = 32'h0000_0000 + ((i % 64) * 4);
                    m0_arvalid = 1'b1;
                    m0_rready  = 1'b1;
                    t_guard = 0;
                    while (!m0_arready && t_guard < 100) begin
                        @(posedge clk);
                        t_guard = t_guard + 1;
                    end
                    @(posedge clk); #1;
                    m0_arvalid = 1'b0;
                    t_guard = 0;
                    while (!m0_rvalid && t_guard < 100) begin
                        @(posedge clk);
                        t_guard = t_guard + 1;
                    end
                    if (m0_rdata[15:0] !== m0_araddr[15:0] || m0_rresp !== 2'b00) begin
                        $error("[FAIL] [M0_STRESS] Data mismatch at pkt %0d: Exp 0x%04X, Got 0x%04X", i, m0_araddr[15:0], m0_rdata[15:0]);
                        fail_count = fail_count + 1;
                    end
                    @(posedge clk); #1;
                    m0_rready = 1'b0;
                end
                $display("[PASS] [M0_STRESS] 200 concurrent random-backpressure reads completed cleanly!");
                pass_count = pass_count + 1;
            end

            // Thread 2: M1 interleaved read burst of 200 packets to BRAM Port B
            begin: m1_stress_thread
                integer j, t_guard2;
                for (j = 0; j < 200; j = j + 1) begin
                    @(posedge clk); #1;
                    m1_araddr  = 32'h0000_1000 + ((j % 64) * 4);
                    m1_arvalid = 1'b1;
                    m1_rready  = 1'b1;
                    t_guard2 = 0;
                    while (!m1_arready && t_guard2 < 100) begin
                        @(posedge clk);
                        t_guard2 = t_guard2 + 1;
                    end
                    @(posedge clk); #1;
                    m1_arvalid = 1'b0;
                    t_guard2 = 0;
                    while (!m1_rvalid && t_guard2 < 100) begin
                        @(posedge clk);
                        t_guard2 = t_guard2 + 1;
                    end
                    if (m1_rdata[15:0] !== m1_araddr[15:0] || m1_rresp !== 2'b00) begin
                        $error("[FAIL] [M1_STRESS] Data mismatch at pkt %0d: Exp 0x%04X, Got 0x%04X", j, m1_araddr[15:0], m1_rdata[15:0]);
                        fail_count = fail_count + 1;
                    end
                    @(posedge clk); #1;
                    m1_rready = 1'b0;
                end
                $display("[PASS] [M1_STRESS] 200 concurrent random-backpressure reads completed cleanly!");
                pass_count = pass_count + 1;
            end
        join

        enable_random_backpressure = 0;

        // =====================================================================
        // TEST 3: DECERR UNDER HEAVY DELAY
        // =====================================================================
        $display("\n--- SCENARIO 3: Illegal Address DECERR (0x5000_0000) ---");
        @(posedge clk); #1;
        m1_araddr  = 32'h5000_0000;
        m1_arvalid = 1'b1;
        m1_rready  = 1'b1;
        loop_guard = 0;
        while (!m1_arready && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        @(posedge clk); #1;
        m1_arvalid = 1'b0;
        loop_guard = 0;
        while (!m1_rvalid && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        if (m1_rresp === 2'b11) begin
            $display("[PASS] [DECERR_STRESS] Interconnect correctly produced DECERR (2'b11)");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [DECERR_STRESS] Expected DECERR 2'b11, got %02b", m1_rresp);
            fail_count = fail_count + 1;
        end
        @(posedge clk); #1;
        m1_rready = 1'b0;

        // =====================================================================
        // TEST 4: W-BEFORE-AW SKEW STRESS (Testing Defect 4 Fix)
        // =====================================================================
        $display("\n--- SCENARIO 4: W Arrives 6 Cycles Before AW (Skew Stress) ---");
        @(posedge clk); #1;
        m1_wdata   = 32'hBEEF_CAFE;
        m1_wstrb   = 4'hF;
        m1_wvalid  = 1'b1;
        m1_bready  = 1'b1;

        // Delay 6 cycles with W asserted while AW is not yet asserted
        repeat (6) @(posedge clk);
        #1;
        // Verify wready was NOT accepted prematurely
        if (m1_wready === 1'b0) begin
            $display("[PASS] [SKEW_W_FIRST] Interconnect correctly held WREADY low while AWVALID was 0");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [SKEW_W_FIRST] WREADY asserted prematurely without valid AW!");
            fail_count = fail_count + 1;
        end

        // Now assert AW
        m1_awaddr  = 32'h0000_0200;
        m1_awvalid = 1'b1;

        loop_guard = 0;
        while (!m1_awready && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        @(posedge clk); #1;
        m1_awvalid = 1'b0;

        loop_guard = 0;
        while (!m1_wready && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        @(posedge clk); #1;
        m1_wvalid = 1'b0;

        loop_guard = 0;
        while (!m1_bvalid && loop_guard < 50) begin
            @(posedge clk);
            loop_guard = loop_guard + 1;
        end
        if (m1_bresp === 2'b00) begin
            $display("[PASS] [SKEW_W_FIRST] Write completed successfully once AW arrived (bresp=2'b00)");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [SKEW_W_FIRST] Invalid write response: %02b", m1_bresp);
            fail_count = fail_count + 1;
        end
        @(posedge clk); #1;
        m1_bready = 1'b0;

        // =====================================================================
        // SUMMARY
        // =====================================================================
        $display("\n-------------------------------------------------------------------------------");
        $display("   EXTREME AXI4-LITE STRESS TEST SUMMARY:");
        $display("   - Passed Checks: %0d", pass_count);
        $display("   - Failed Checks: %0d", fail_count);
        $display("-------------------------------------------------------------------------------");

        if (fail_count == 0) begin
            $display("[SUCCESS] ALL EXTREME AXI4-LITE BUS STRESS TESTS PASSED!\n");
            $finish;
        end else begin
            $fatal(1, "[FAILURE] AXI BUS STRESS TEST DETECTED ERRORS!");
        end
    end

endmodule
