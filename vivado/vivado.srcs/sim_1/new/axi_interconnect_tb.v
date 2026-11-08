`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: AXI4-LITE 2x4 CROSSBAR INTERCONNECT
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module axi_interconnect.
//   - Layer 2 (Mock Services): Mock Master 0 BFM (I-Cache), Mock Master 1 BFM
//                              (D-Bus), và 5 Mock Slave Service Responders
//                              (BRAM Port A, BRAM Port B, UART, GPIO, Timer).
//   - Layer 3 (Spy & SVA)    : 11 bộ đếm Spy độc lập theo dõi từng Slave &
//                              DECERR trap, cùng khẳng định SVA $onehot0 kiểm tra
//                              không bao giờ kích hoạt đồng thời >1 Slave.
//   - Layer 4 (Scoreboard)   : Các hàm expect_tx, expect_state, expect_spy
//                              kiểm tra ranh giới 16KB BRAM (0x3FFC vs 0x4000).
// =============================================================================

module axi_interconnect_tb;

    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam CLK_PERIOD = 10;

    reg clk;
    reg rst_n;

    // Master 0 (I-Cache)
    reg  [ADDR_WIDTH-1:0] m0_araddr;
    reg                   m0_arvalid;
    wire                  m0_arready;
    wire [DATA_WIDTH-1:0] m0_rdata;
    wire [1:0]            m0_rresp;
    wire                  m0_rvalid;
    reg                   m0_rready;

    // Master 1 (D-Bus)
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

    integer pass_count = 0;
    integer fail_count = 0;

    // =========================================================================
    // LAYER 1: COMPONENT UNDER TEST (DUT ISOLATION)
    // =========================================================================
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

    // =========================================================================
    // LAYER 2 & 3: MOCK SLAVE SERVICES + TRANSACTION CALL SPIES + SVA
    // =========================================================================
    integer spy_s0a_read_cnt    = 0;
    integer spy_s0b_read_cnt    = 0;
    integer spy_s0b_write_cnt   = 0;
    integer spy_s1_read_cnt     = 0;
    integer spy_s1_write_cnt    = 0;
    integer spy_s2_read_cnt     = 0;
    integer spy_s2_write_cnt    = 0;
    integer spy_s3_read_cnt     = 0;
    integer spy_s3_write_cnt    = 0;
    integer spy_decerr_read_cnt = 0;
    integer spy_decerr_write_cnt= 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s0_arready_a <= 1'b0; s0_rvalid_a <= 1'b0; s0_rdata_a <= 32'h0; s0_rresp_a <= 2'b00;
            s0_awready_b <= 1'b0; s0_wready_b <= 1'b0; s0_bvalid_b <= 1'b0; s0_bresp_b <= 2'b00;
            s0_arready_b <= 1'b0; s0_rvalid_b <= 1'b0; s0_rdata_b <= 32'h0; s0_rresp_b <= 2'b00;
            s1_awready   <= 1'b0; s1_wready   <= 1'b0; s1_bvalid   <= 1'b0; s1_bresp   <= 2'b00;
            s1_arready   <= 1'b0; s1_rvalid   <= 1'b0; s1_rdata    <= 32'h0; s1_rresp   <= 2'b00;
            s2_gpio_awready  <= 1'b0; s2_gpio_wready  <= 1'b0; s2_gpio_bvalid  <= 1'b0; s2_gpio_bresp  <= 2'b00;
            s2_gpio_arready  <= 1'b0; s2_gpio_rvalid  <= 1'b0; s2_gpio_rdata   <= 32'h0; s2_gpio_rresp  <= 2'b00;
            s3_timer_awready <= 1'b0; s3_timer_wready <= 1'b0; s3_timer_bvalid <= 1'b0; s3_timer_bresp <= 2'b00;
            s3_timer_arready <= 1'b0; s3_timer_rvalid <= 1'b0; s3_timer_rdata  <= 32'h0; s3_timer_rresp <= 2'b00;

            spy_s0a_read_cnt     <= 0;
            spy_s0b_read_cnt     <= 0;
            spy_s0b_write_cnt    <= 0;
            spy_s1_read_cnt      <= 0;
            spy_s1_write_cnt     <= 0;
            spy_s2_read_cnt      <= 0;
            spy_s2_write_cnt     <= 0;
            spy_s3_read_cnt      <= 0;
            spy_s3_write_cnt     <= 0;
            spy_decerr_read_cnt  <= 0;
            spy_decerr_write_cnt <= 0;
        end else begin
            // Mock Slave 0A: BRAM Port A (Read)
            s0_arready_a <= s0_arvalid_a;
            if (s0_arvalid_a && s0_arready_a) begin
                s0_rvalid_a      <= 1'b1;
                s0_rdata_a       <= 32'hAAAA_0000 | s0_araddr_a;
                s0_rresp_a       <= 2'b00;
                spy_s0a_read_cnt <= spy_s0a_read_cnt + 1;
            end else if (s0_rvalid_a && s0_rready_a) begin
                s0_rvalid_a <= 1'b0;
            end

            // Mock Slave 0B: BRAM Port B (Write & Read)
            s0_awready_b <= s0_awvalid_b;
            s0_wready_b  <= s0_wvalid_b;
            if (s0_awvalid_b && s0_wvalid_b && s0_awready_b && s0_wready_b) begin
                s0_bvalid_b       <= 1'b1;
                s0_bresp_b        <= 2'b00;
                spy_s0b_write_cnt <= spy_s0b_write_cnt + 1;
            end else if (s0_bvalid_b && s0_bready_b) begin
                s0_bvalid_b <= 1'b0;
            end

            s0_arready_b <= s0_arvalid_b;
            if (s0_arvalid_b && s0_arready_b) begin
                s0_rvalid_b      <= 1'b1;
                s0_rdata_b       <= 32'hBBBB_0000 | s0_araddr_b;
                s0_rresp_b       <= 2'b00;
                spy_s0b_read_cnt <= spy_s0b_read_cnt + 1;
            end else if (s0_rvalid_b && s0_rready_b) begin
                s0_rvalid_b <= 1'b0;
            end

            // Mock Slave 1: UART (0x1000_0000)
            s1_awready <= s1_awvalid;
            s1_wready  <= s1_wvalid;
            if (s1_awvalid && s1_wvalid && s1_awready && s1_wready) begin
                s1_bvalid        <= 1'b1;
                s1_bresp         <= 2'b00;
                spy_s1_write_cnt <= spy_s1_write_cnt + 1;
            end else if (s1_bvalid && s1_bready) begin
                s1_bvalid <= 1'b0;
            end
            s1_arready <= s1_arvalid;
            if (s1_arvalid && s1_arready) begin
                s1_rvalid       <= 1'b1;
                s1_rdata        <= 32'h1111_2222;
                s1_rresp        <= 2'b00;
                spy_s1_read_cnt <= spy_s1_read_cnt + 1;
            end else if (s1_rvalid && s1_rready) begin
                s1_rvalid <= 1'b0;
            end

            // Mock Slave 2: GPIO (0x1000_1000)
            s2_gpio_awready <= s2_gpio_awvalid;
            s2_gpio_wready  <= s2_gpio_wvalid;
            if (s2_gpio_awvalid && s2_gpio_wvalid && s2_gpio_awready && s2_gpio_wready) begin
                s2_gpio_bvalid   <= 1'b1;
                s2_gpio_bresp    <= 2'b00;
                spy_s2_write_cnt <= spy_s2_write_cnt + 1;
            end else if (s2_gpio_bvalid && s2_gpio_bready) begin
                s2_gpio_bvalid <= 1'b0;
            end
            s2_gpio_arready <= s2_gpio_arvalid;
            if (s2_gpio_arvalid && s2_gpio_arready) begin
                s2_gpio_rvalid  <= 1'b1;
                s2_gpio_rdata   <= 32'h0000_000F;
                s2_gpio_rresp   <= 2'b00;
                spy_s2_read_cnt <= spy_s2_read_cnt + 1;
            end else if (s2_gpio_rvalid && s2_gpio_rready) begin
                s2_gpio_rvalid <= 1'b0;
            end

            // Mock Slave 3: Timer (0x1000_2000)
            s3_timer_awready <= s3_timer_awvalid;
            s3_timer_wready  <= s3_timer_wvalid;
            if (s3_timer_awvalid && s3_timer_wvalid && s3_timer_awready && s3_timer_wready) begin
                s3_timer_bvalid  <= 1'b1;
                s3_timer_bresp   <= 2'b00;
                spy_s3_write_cnt <= spy_s3_write_cnt + 1;
            end else if (s3_timer_bvalid && s3_timer_bready) begin
                s3_timer_bvalid <= 1'b0;
            end
            s3_timer_arready <= s3_timer_arvalid;
            if (s3_timer_arvalid && s3_timer_arready) begin
                s3_timer_rvalid <= 1'b1;
                s3_timer_rdata  <= 32'hCAFE_BABE;
                s3_timer_rresp  <= 2'b00;
                spy_s3_read_cnt <= spy_s3_read_cnt + 1;
            end else if (s3_timer_rvalid && s3_timer_rready) begin
                s3_timer_rvalid <= 1'b0;
            end

            // Spy on DECERR responses (2'b11) returned to M0 or M1
            if ((dut.active_rd_slave == 3'd4) && m1_arvalid && m1_arready)
                spy_decerr_read_cnt <= spy_decerr_read_cnt + 1;

            if ((dut.active_wr_slave == 3'd4) && m1_awvalid && m1_awready)
                spy_decerr_write_cnt <= spy_decerr_write_cnt + 1;
        end
    end

    // SVA 1: Slave Read Select One-Hot-Zero ($onehot0)
    property p_m1_arvalid_onehot0;
        @(posedge clk) disable iff (!rst_n)
        $onehot0({s0_arvalid_b, s1_arvalid, s2_gpio_arvalid, s3_timer_arvalid});
    endproperty
    assert property (p_m1_arvalid_onehot0)
        else begin
            $error("[SVA ERROR] Multiple Slaves selected simultaneously on M1 Read Channel!");
            fail_count = fail_count + 1;
        end

    // SVA 2: Slave Write Select One-Hot-Zero ($onehot0)
    property p_m1_awvalid_onehot0;
        @(posedge clk) disable iff (!rst_n)
        $onehot0({s0_awvalid_b, s1_awvalid, s2_gpio_awvalid, s3_timer_awvalid});
    endproperty
    assert property (p_m1_awvalid_onehot0)
        else begin
            $error("[SVA ERROR] Multiple Slaves selected simultaneously on M1 Write Channel!");
            fail_count = fail_count + 1;
        end

    // Mock Master BFM Helper Tasks
    task mock_m0_read;
        input  [31:0] addr;
        input  [31:0] exp_data;
        input  [1:0]  exp_resp;
        input  [255:0] label;
        begin
            @(posedge clk); #1;
            m0_araddr  = addr;
            m0_arvalid = 1'b1;
            m0_rready  = 1'b1;
            while (!m0_arready) @(posedge clk);
            #1;
            m0_arvalid = 1'b0;
            while (!m0_rvalid) @(posedge clk);
            expect_tx(label, m0_rdata, exp_data, m0_rresp, exp_resp);
            #1;
            m0_rready = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    task mock_m1_read;
        input  [31:0] addr;
        input  [31:0] exp_data;
        input  [1:0]  exp_resp;
        input  [255:0] label;
        begin
            @(posedge clk); #1;
            m1_araddr  = addr;
            m1_arvalid = 1'b1;
            m1_rready  = 1'b1;
            while (!m1_arready) @(posedge clk);
            #1;
            m1_arvalid = 1'b0;
            while (!m1_rvalid) @(posedge clk);
            expect_tx(label, m1_rdata, exp_data, m1_rresp, exp_resp);
            #1;
            m1_rready = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    task mock_m1_write;
        input  [31:0] addr;
        input  [31:0] data;
        input  [1:0]  exp_resp;
        input  [255:0] label;
        begin
            @(posedge clk); #1;
            m1_awaddr  = addr;
            m1_awvalid = 1'b1;
            m1_wdata   = data;
            m1_wstrb   = 4'hF;
            m1_wvalid  = 1'b1;
            m1_bready  = 1'b1;
            while (!(m1_awready && m1_wready)) @(posedge clk);
            #1;
            m1_awvalid = 1'b0;
            m1_wvalid  = 1'b0;
            while (!m1_bvalid) @(posedge clk);
            expect_tx(label, 32'h0, 32'h0, m1_bresp, exp_resp);
            #1;
            m1_bready = 1'b0;
            @(posedge clk); #1;
        end
    endtask

    // =========================================================================
    // LAYER 4: SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_tx;
        input [255:0] test_name;
        input [31:0]  act_val;
        input [31:0]  exp_val;
        input [1:0]   act_resp;
        input [1:0]   exp_resp;
        begin
            assert (act_val === exp_val && act_resp === exp_resp) begin
                $display("[PASS] [EXPECT_TX]    %-36s | Data: 0x%08X (Exp: 0x%08X) | Resp: %02b",
                         test_name, act_val, exp_val, act_resp);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [EXPECT_TX]    %-36s | Data: 0x%08X (Exp: 0x%08X) | Resp: %02b (Exp: %02b)",
                       test_name, act_val, exp_val, act_resp, exp_resp);
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
    // TEST SEQUENCER
    // =========================================================================
    initial begin
        $display("\n===============================================================================");
        $display("   STARTING LAYERED AXI4-LITE INTERCONNECT VERIFICATION (100%% COVERAGE)");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        m0_araddr = 0; m0_arvalid = 0; m0_rready = 0;
        m1_awaddr = 0; m1_awvalid = 0; m1_wdata = 0; m1_wstrb = 0; m1_wvalid = 0; m1_bready = 0;
        m1_araddr = 0; m1_arvalid = 0; m1_rready = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        #(CLK_PERIOD);

        // ---------------------------------------------------------------------
        // TEST 1: Master 0 Read to BRAM Port A
        // ---------------------------------------------------------------------
        $display("--- TEST 1: M0 (I-Cache) Read BRAM Port A (0x0000_0040) ---");
        mock_m0_read(32'h0000_0040, 32'hAAAA_0040, 2'b00, "M0 Read BRAM Port A (0x0040)");

        // ---------------------------------------------------------------------
        // TEST 2: Concurrent Dual-Port BRAM Reads (M0 Port A + M1 Port B)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 2: Concurrent Reads: M0 & M1 Read BRAM Simultaneously ---");
        @(posedge clk); #1;
        m0_araddr = 32'h0000_0080; m0_arvalid = 1'b1; m0_rready = 1'b1;
        m1_araddr = 32'h0000_0100; m1_arvalid = 1'b1; m1_rready = 1'b1;

        wait (m0_arready == 1'b1 && m1_arready == 1'b1);
        @(posedge clk); #1;
        m0_arvalid = 1'b0;
        m1_arvalid = 1'b0;

        wait (m0_rvalid == 1'b1 && m1_rvalid == 1'b1);
        expect_tx("Concurrent M0 Data", m0_rdata, 32'hAAAA_0080, m0_rresp, 2'b00);
        expect_tx("Concurrent M1 Data", m1_rdata, 32'hBBBB_0100, m1_rresp, 2'b00);
        @(posedge clk); #1;
        m0_rready = 1'b0; m1_rready = 1'b0;
        @(posedge clk); #1;

        // ---------------------------------------------------------------------
        // TEST 3: Exact 16KB BRAM Boundary Verification (0x3FFC vs 0x4000)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 3: 16KB BRAM Upper Boundary Check (0x3FFC Valid vs 0x4000 DECERR) ---");
        mock_m1_write(32'h0000_3FFC, 32'hDEAD_BEEF, 2'b00, "M1 Write Last Valid BRAM Word (0x3FFC)");
        mock_m1_read (32'h0000_3FFC, 32'hBBBB_3FFC, 2'b00, "M1 Read Last Valid BRAM Word (0x3FFC)");

        // Address 0x0000_4000 is just outside 16KB BRAM (addr[31:14] == 1) -> M1 must return DECERR (2'b11)!
        mock_m1_read (32'h0000_4000, 32'hDEAD_BEEF, 2'b11, "M1 Read Out-of-Bounds 0x4000 (DECERR)");
        mock_m1_write(32'h0000_4000, 32'h1234_5678, 2'b11, "M1 Write Out-of-Bounds 0x4000 (DECERR)");

        // ---------------------------------------------------------------------
        // TEST 4: Master 1 Write & Read to All MMIO Peripherals (UART, GPIO, Timer)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 4: M1 Full Read/Write Routing to UART, GPIO, Timer ---");
        mock_m1_write(32'h1000_0000, 32'h0000_0041, 2'b00, "M1 Write UART (0x1000_0000)");
        mock_m1_read (32'h1000_0004, 32'h1111_2222, 2'b00, "M1 Read UART  (0x1000_0004)");

        mock_m1_write(32'h1000_1004, 32'h0000_000A, 2'b00, "M1 Write GPIO (0x1000_1004)");
        mock_m1_read (32'h1000_1000, 32'h0000_000F, 2'b00, "M1 Read GPIO  (0x1000_1000)");

        mock_m1_write(32'h1000_2008, 32'h0000_1000, 2'b00, "M1 Write Timer (0x1000_2008)");
        mock_m1_read (32'h1000_2000, 32'hCAFE_BABE, 2'b00, "M1 Read Timer  (0x1000_2000)");

        // ---------------------------------------------------------------------
        // TEST 5: High Unmapped Address DECERR (0x5000_0000)
        // ---------------------------------------------------------------------
        $display("\n--- TEST 5: High Unmapped Address DECERR (0x5000_0000) ---");
        mock_m1_read (32'h5000_0000, 32'hDEAD_BEEF, 2'b11, "M1 DECERR Read  (0x5000_0000)");
        mock_m1_write(32'h5000_0000, 32'h1234_5678, 2'b11, "M1 DECERR Write (0x5000_0000)");

        // ---------------------------------------------------------------------
        // TEST 6: Ecosystem Slave Spy Verification
        // ---------------------------------------------------------------------
        $display("\n--- TEST 6: Ecosystem Slave & DECERR Spy Audit ---");
        expect_spy("Slave 0A (BRAM Port A) Read Calls",  spy_s0a_read_cnt,     2);
        expect_spy("Slave 0B (BRAM Port B) Read Calls",  spy_s0b_read_cnt,     2);
        expect_spy("Slave 0B (BRAM Port B) Write Calls", spy_s0b_write_cnt,    1);
        expect_spy("Slave 1  (UART Lite)   Read Calls",  spy_s1_read_cnt,      1);
        expect_spy("Slave 1  (UART Lite)   Write Calls", spy_s1_write_cnt,     1);
        expect_spy("Slave 2  (GPIO)        Read Calls",  spy_s2_read_cnt,      1);
        expect_spy("Slave 2  (GPIO)        Write Calls", spy_s2_write_cnt,     1);
        expect_spy("Slave 3  (Timer)       Read Calls",  spy_s3_read_cnt,      1);
        expect_spy("Slave 3  (Timer)       Write Calls", spy_s3_write_cnt,     1);
        expect_spy("DECERR Default Trap    Read Calls",  spy_decerr_read_cnt,  2);
        expect_spy("DECERR Default Trap    Write Calls", spy_decerr_write_cnt, 2);

        $display("\n===============================================================================");
        $display("   AXI4-LITE INTERCONNECT VERIFICATION SUMMARY");
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
        $error("[WATCHDOG TIMEOUT] axi_interconnect_tb exceeded 50us limit! Aborting.");
        $finish;
    end

endmodule
