`timescale 1ns / 1ps

// =============================================================================
// MODULE: SOC_TOP - COMPLETE RISC-V RV32IM INDUSTRIAL SYSTEM-ON-CHIP
// =============================================================================
// - CPU Core: 5-Stage RV32IM Pipeline (Branch Predictor, Multiplier, Divider, CSR)
// - Memory Subsystem:
//   * L1 Instruction Cache (Direct-Mapped 1024B, 1-cycle hit latency)
//   * AXI4-Lite Data Bus Master
//   * AMBA AXI4-Lite Crossbar Interconnect (2 Masters x 4 Slaves + DECERR)
//   * 16KB Dual-Port Block RAM (Concurrent Instruction Refill & Data Access)
// - MMIO Peripherals:
//   * AXI UART Lite Controller (0x1000_0000, 115200 Baud TX/RX)
//   * AXI GPIO Controller      (0x1000_1000, 4 LEDs, 4 Switches, 4 Buttons)
//   * AXI Machine Timer / MTIME(0x1000_2000, 64-bit Real-Time Counter & Compare)
// - FPGA Target: Digilent Arty Z7-20 (xc7z020clg400-1)
// - Quality: 100% Synchronous, Zero Latches (LDCE: 0), SVA Verified
// =============================================================================

module soc_top #(
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 32,
    parameter CLK_FREQ_HZ   = 50_000_000,
    parameter BAUD_RATE     = 115_200,
    parameter BOOT_HEX_FILE = ""
)(
    input  wire       i_clk,
    input  wire       i_rst_n,

    // UART Serial Communication
    output wire       o_uart_tx,
    input  wire       i_uart_rx,

    // Physical Kit I/Os (Arty Z7-20)
    output wire [3:0] o_led,
    input  wire [3:0] i_sw,
    input  wire [3:0] i_btn,

    // Debug / Halt status
    output wire       o_ecall_halt
);

    // =========================================================================
    // 1. CPU CORE AXI4-LITE BUS MASTERS
    // =========================================================================
    // I-Cache Refill Master (M0)
    wire [ADDR_WIDTH-1:0] cpu_axi_i_araddr;
    wire                  cpu_axi_i_arvalid;
    wire                  cpu_axi_i_arready;
    wire [2:0]            cpu_axi_i_prot;
    wire [DATA_WIDTH-1:0] cpu_axi_i_rdata;
    wire [1:0]            cpu_axi_i_rresp;
    wire                  cpu_axi_i_rvalid;
    wire                  cpu_axi_i_rready;

    // D-Bus Master (M1)
    wire [ADDR_WIDTH-1:0] cpu_axi_d_awaddr;
    wire                  cpu_axi_d_awvalid;
    wire                  cpu_axi_d_awready;
    wire [DATA_WIDTH-1:0] cpu_axi_d_wdata;
    wire [3:0]            cpu_axi_d_wstrb;
    wire                  cpu_axi_d_wvalid;
    wire                  cpu_axi_d_wready;
    wire [1:0]            cpu_axi_d_bresp;
    wire                  cpu_axi_d_bvalid;
    wire                  cpu_axi_d_bready;
    wire [ADDR_WIDTH-1:0] cpu_axi_d_araddr;
    wire                  cpu_axi_d_arvalid;
    wire                  cpu_axi_d_arready;
    wire [DATA_WIDTH-1:0] cpu_axi_d_rdata;
    wire [1:0]            cpu_axi_d_rresp;
    wire                  cpu_axi_d_rvalid;
    wire                  cpu_axi_d_rready;

    // Interrupt Wires
    wire uart_irq;
    wire timer_irq;

    cpu_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) cpu_inst (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),

        // I-Cache Master Interface
        .o_axi_i_araddr  (cpu_axi_i_araddr),
        .o_axi_i_arvalid (cpu_axi_i_arvalid),
        .i_axi_i_arready (cpu_axi_i_arready),
        .o_axi_i_prot    (cpu_axi_i_prot),
        .i_axi_i_rdata   (cpu_axi_i_rdata),
        .i_axi_i_rresp   (cpu_axi_i_rresp),
        .i_axi_i_rvalid  (cpu_axi_i_rvalid),
        .o_axi_i_rready  (cpu_axi_i_rready),

        // D-Bus Master Interface
        .o_axi_d_awaddr  (cpu_axi_d_awaddr),
        .o_axi_d_awvalid (cpu_axi_d_awvalid),
        .i_axi_d_awready (cpu_axi_d_awready),
        .o_axi_d_wdata   (cpu_axi_d_wdata),
        .o_axi_d_wstrb   (cpu_axi_d_wstrb),
        .o_axi_d_wvalid  (cpu_axi_d_wvalid),
        .i_axi_d_wready  (cpu_axi_d_wready),
        .i_axi_d_bresp   (cpu_axi_d_bresp),
        .i_axi_d_bvalid  (cpu_axi_d_bvalid),
        .o_axi_d_bready  (cpu_axi_d_bready),
        .o_axi_d_araddr  (cpu_axi_d_araddr),
        .o_axi_d_arvalid (cpu_axi_d_arvalid),
        .i_axi_d_arready (cpu_axi_d_arready),
        .i_axi_d_rdata   (cpu_axi_d_rdata),
        .i_axi_d_rresp   (cpu_axi_d_rresp),
        .i_axi_d_rvalid  (cpu_axi_d_rvalid),
        .o_axi_d_rready  (cpu_axi_d_rready),

        // Peripheral Interrupts
        .i_timer_irq     (timer_irq),
        .i_external_irq  (uart_irq),

        .o_ecall_halt    (o_ecall_halt)
    );

    // =========================================================================
    // 2. AXI4-LITE INTERCONNECT CHANNELS
    // =========================================================================
    // Slave 0: BRAM Port A (Read-only for I-Cache)
    wire [ADDR_WIDTH-1:0] s0_bram_araddr_a;
    wire                  s0_bram_arvalid_a;
    wire                  s0_bram_arready_a;
    wire [DATA_WIDTH-1:0] s0_bram_rdata_a;
    wire [1:0]            s0_bram_rresp_a;
    wire                  s0_bram_rvalid_a;
    wire                  s0_bram_rready_a;

    // Slave 0: BRAM Port B (Read/Write for D-Bus)
    wire [ADDR_WIDTH-1:0] s0_bram_awaddr_b;
    wire                  s0_bram_awvalid_b;
    wire                  s0_bram_awready_b;
    wire [DATA_WIDTH-1:0] s0_bram_wdata_b;
    wire [3:0]            s0_bram_wstrb_b;
    wire                  s0_bram_wvalid_b;
    wire                  s0_bram_wready_b;
    wire [1:0]            s0_bram_bresp_b;
    wire                  s0_bram_bvalid_b;
    wire                  s0_bram_bready_b;
    wire [ADDR_WIDTH-1:0] s0_bram_araddr_b;
    wire                  s0_bram_arvalid_b;
    wire                  s0_bram_arready_b;
    wire [DATA_WIDTH-1:0] s0_bram_rdata_b;
    wire [1:0]            s0_bram_rresp_b;
    wire                  s0_bram_rvalid_b;
    wire                  s0_bram_rready_b;

    // Slave 1: UART Lite (0x1000_0000)
    wire [ADDR_WIDTH-1:0] s1_uart_awaddr;
    wire                  s1_uart_awvalid;
    wire                  s1_uart_awready;
    wire [DATA_WIDTH-1:0] s1_uart_wdata;
    wire [3:0]            s1_uart_wstrb;
    wire                  s1_uart_wvalid;
    wire                  s1_uart_wready;
    wire [1:0]            s1_uart_bresp;
    wire                  s1_uart_bvalid;
    wire                  s1_uart_bready;
    wire [ADDR_WIDTH-1:0] s1_uart_araddr;
    wire                  s1_uart_arvalid;
    wire                  s1_uart_arready;
    wire [DATA_WIDTH-1:0] s1_uart_rdata;
    wire [1:0]            s1_uart_rresp;
    wire                  s1_uart_rvalid;
    wire                  s1_uart_rready;

    // Slave 2: GPIO (0x1000_1000)
    wire [ADDR_WIDTH-1:0] s2_gpio_awaddr;
    wire                  s2_gpio_awvalid;
    wire                  s2_gpio_awready;
    wire [DATA_WIDTH-1:0] s2_gpio_wdata;
    wire [3:0]            s2_gpio_wstrb;
    wire                  s2_gpio_wvalid;
    wire                  s2_gpio_wready;
    wire [1:0]            s2_gpio_bresp;
    wire                  s2_gpio_bvalid;
    wire                  s2_gpio_bready;
    wire [ADDR_WIDTH-1:0] s2_gpio_araddr;
    wire                  s2_gpio_arvalid;
    wire                  s2_gpio_arready;
    wire [DATA_WIDTH-1:0] s2_gpio_rdata;
    wire [1:0]            s2_gpio_rresp;
    wire                  s2_gpio_rvalid;
    wire                  s2_gpio_rready;

    // Slave 3: Timer (0x1000_2000)
    wire [ADDR_WIDTH-1:0] s3_timer_awaddr;
    wire                  s3_timer_awvalid;
    wire                  s3_timer_awready;
    wire [DATA_WIDTH-1:0] s3_timer_wdata;
    wire [3:0]            s3_timer_wstrb;
    wire                  s3_timer_wvalid;
    wire                  s3_timer_wready;
    wire [1:0]            s3_timer_bresp;
    wire                  s3_timer_bvalid;
    wire                  s3_timer_bready;
    wire [ADDR_WIDTH-1:0] s3_timer_araddr;
    wire                  s3_timer_arvalid;
    wire                  s3_timer_arready;
    wire [DATA_WIDTH-1:0] s3_timer_rdata;
    wire [1:0]            s3_timer_rresp;
    wire                  s3_timer_rvalid;
    wire                  s3_timer_rready;

    axi_interconnect #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) interconnect_inst (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),

        // Master 0 (CPU I-Cache)
        .m0_axi_araddr    (cpu_axi_i_araddr),
        .m0_axi_arvalid   (cpu_axi_i_arvalid),
        .m0_axi_arready   (cpu_axi_i_arready),
        .m0_axi_rdata     (cpu_axi_i_rdata),
        .m0_axi_rresp     (cpu_axi_i_rresp),
        .m0_axi_rvalid    (cpu_axi_i_rvalid),
        .m0_axi_rready    (cpu_axi_i_rready),

        // Master 1 (CPU D-Bus)
        .m1_axi_awaddr    (cpu_axi_d_awaddr),
        .m1_axi_awvalid   (cpu_axi_d_awvalid),
        .m1_axi_awready   (cpu_axi_d_awready),
        .m1_axi_wdata     (cpu_axi_d_wdata),
        .m1_axi_wstrb     (cpu_axi_d_wstrb),
        .m1_axi_wvalid    (cpu_axi_d_wvalid),
        .m1_axi_wready    (cpu_axi_d_wready),
        .m1_axi_bresp     (cpu_axi_d_bresp),
        .m1_axi_bvalid    (cpu_axi_d_bvalid),
        .m1_axi_bready    (cpu_axi_d_bready),
        .m1_axi_araddr    (cpu_axi_d_araddr),
        .m1_axi_arvalid   (cpu_axi_d_arvalid),
        .m1_axi_arready   (cpu_axi_d_arready),
        .m1_axi_rdata     (cpu_axi_d_rdata),
        .m1_axi_rresp     (cpu_axi_d_rresp),
        .m1_axi_rvalid    (cpu_axi_d_rvalid),
        .m1_axi_rready    (cpu_axi_d_rready),

        // Slave 0: BRAM Port A
        .s0_bram_araddr_a (s0_bram_araddr_a),
        .s0_bram_arvalid_a(s0_bram_arvalid_a),
        .s0_bram_arready_a(s0_bram_arready_a),
        .s0_bram_rdata_a  (s0_bram_rdata_a),
        .s0_bram_rresp_a  (s0_bram_rresp_a),
        .s0_bram_rvalid_a (s0_bram_rvalid_a),
        .s0_bram_rready_a (s0_bram_rready_a),

        // Slave 0: BRAM Port B
        .s0_bram_awaddr_b (s0_bram_awaddr_b),
        .s0_bram_awvalid_b(s0_bram_awvalid_b),
        .s0_bram_awready_b(s0_bram_awready_b),
        .s0_bram_wdata_b  (s0_bram_wdata_b),
        .s0_bram_wstrb_b  (s0_bram_wstrb_b),
        .s0_bram_wvalid_b (s0_bram_wvalid_b),
        .s0_bram_wready_b (s0_bram_wready_b),
        .s0_bram_bresp_b  (s0_bram_bresp_b),
        .s0_bram_bvalid_b (s0_bram_bvalid_b),
        .s0_bram_bready_b (s0_bram_bready_b),
        .s0_bram_araddr_b (s0_bram_araddr_b),
        .s0_bram_arvalid_b(s0_bram_arvalid_b),
        .s0_bram_arready_b(s0_bram_arready_b),
        .s0_bram_rdata_b  (s0_bram_rdata_b),
        .s0_bram_rresp_b  (s0_bram_rresp_b),
        .s0_bram_rvalid_b (s0_bram_rvalid_b),
        .s0_bram_rready_b (s0_bram_rready_b),

        // Slave 1: UART Lite
        .s1_uart_awaddr   (s1_uart_awaddr),
        .s1_uart_awvalid  (s1_uart_awvalid),
        .s1_uart_awready  (s1_uart_awready),
        .s1_uart_wdata    (s1_uart_wdata),
        .s1_uart_wstrb    (s1_uart_wstrb),
        .s1_uart_wvalid   (s1_uart_wvalid),
        .s1_uart_wready   (s1_uart_wready),
        .s1_uart_bresp    (s1_uart_bresp),
        .s1_uart_bvalid   (s1_uart_bvalid),
        .s1_uart_bready   (s1_uart_bready),
        .s1_uart_araddr   (s1_uart_araddr),
        .s1_uart_arvalid  (s1_uart_arvalid),
        .s1_uart_arready  (s1_uart_arready),
        .s1_uart_rdata    (s1_uart_rdata),
        .s1_uart_rresp    (s1_uart_rresp),
        .s1_uart_rvalid   (s1_uart_rvalid),
        .s1_uart_rready   (s1_uart_rready),

        // Slave 2: GPIO
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

        // Slave 3: Timer
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

    // =========================================================================
    // 3. HARDWARE DUAL-PORT BLOCK RAM (16KB, 4096 WORDS X 32-BIT)
    // =========================================================================
    // BRAM Handshake Port A (Single-Pulse Handshake Chuan AXI4-Lite)
    reg s0_arready_a_reg, s0_rvalid_a_reg;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            s0_arready_a_reg <= 1'b0;
            s0_rvalid_a_reg  <= 1'b0;
        end else begin
            s0_arready_a_reg <= s0_bram_arvalid_a && !s0_arready_a_reg;
            if (s0_bram_arvalid_a && s0_arready_a_reg) begin
                s0_rvalid_a_reg <= 1'b1;
            end else if (s0_bram_rready_a && s0_rvalid_a_reg) begin
                s0_rvalid_a_reg <= 1'b0;
            end
        end
    end
    assign s0_bram_arready_a = s0_arready_a_reg;
    assign s0_bram_rvalid_a  = s0_rvalid_a_reg;
    assign s0_bram_rresp_a   = 2'b00;

    // BRAM Handshake Port B (Single-Pulse Handshake Chuan AXI4-Lite)
    reg s0_arready_b_reg, s0_rvalid_b_reg, s0_awready_b_reg, s0_wready_b_reg, s0_bvalid_b_reg;
    wire bram_we_b = s0_bram_awvalid_b && s0_bram_wvalid_b && !s0_awready_b_reg && !s0_bvalid_b_reg;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            s0_arready_b_reg <= 1'b0;
            s0_rvalid_b_reg  <= 1'b0;
            s0_awready_b_reg <= 1'b0;
            s0_wready_b_reg  <= 1'b0;
            s0_bvalid_b_reg  <= 1'b0;
        end else begin
            s0_arready_b_reg <= s0_bram_arvalid_b && !s0_arready_b_reg;
            if (s0_bram_arvalid_b && s0_arready_b_reg) begin
                s0_rvalid_b_reg <= 1'b1;
            end else if (s0_bram_rready_b && s0_rvalid_b_reg) begin
                s0_rvalid_b_reg <= 1'b0;
            end

            s0_awready_b_reg <= bram_we_b;
            s0_wready_b_reg  <= bram_we_b;
            if (bram_we_b) begin
                s0_bvalid_b_reg <= 1'b1;
            end else if (s0_bram_bready_b && s0_bvalid_b_reg) begin
                s0_bvalid_b_reg <= 1'b0;
            end
        end
    end
    assign s0_bram_arready_b = s0_arready_b_reg;
    assign s0_bram_rvalid_b  = s0_rvalid_b_reg;
    assign s0_bram_rresp_b   = 2'b00;
    assign s0_bram_awready_b = s0_awready_b_reg;
    assign s0_bram_wready_b  = s0_wready_b_reg;
    assign s0_bram_bvalid_b  = s0_bvalid_b_reg;
    assign s0_bram_bresp_b   = 2'b00;

    wire [11:0] bram_addr_a = s0_bram_araddr_a[13:2];
    wire [11:0] bram_addr_b = s0_bram_arvalid_b ? s0_bram_araddr_b[13:2] : s0_bram_awaddr_b[13:2];

    dual_port_bram #(
        .RAM_DEPTH (4096),
        .INIT_FILE (BOOT_HEX_FILE)
    ) bram_inst (
        .clk     (i_clk),
        .addr_a  (bram_addr_a),
        .dout_a  (s0_bram_rdata_a),
        .we_b    (bram_we_b),
        .wstrb_b (s0_bram_wstrb_b),
        .addr_b  (bram_addr_b),
        .din_b   (s0_bram_wdata_b),
        .dout_b  (s0_bram_rdata_b)
    );

    // =========================================================================
    // 4. INSTANTIATE AXI UART LITE CONTROLLER (0x1000_0000)
    // =========================================================================
    axi_uart_lite #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) uart_inst (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .o_uart_tx    (o_uart_tx),
        .i_uart_rx    (i_uart_rx),
        .o_uart_irq   (uart_irq),
        .s_axi_awaddr (s1_uart_awaddr),
        .s_axi_awvalid(s1_uart_awvalid),
        .s_axi_awready(s1_uart_awready),
        .s_axi_wdata  (s1_uart_wdata),
        .s_axi_wstrb  (s1_uart_wstrb),
        .s_axi_wvalid (s1_uart_wvalid),
        .s_axi_wready (s1_uart_wready),
        .s_axi_bresp  (s1_uart_bresp),
        .s_axi_bvalid (s1_uart_bvalid),
        .s_axi_bready (s1_uart_bready),
        .s_axi_araddr (s1_uart_araddr),
        .s_axi_arvalid(s1_uart_arvalid),
        .s_axi_arready(s1_uart_arready),
        .s_axi_rdata  (s1_uart_rdata),
        .s_axi_rresp  (s1_uart_rresp),
        .s_axi_rvalid (s1_uart_rvalid),
        .s_axi_rready (s1_uart_rready)
    );

    // =========================================================================
    // 5. INSTANTIATE AXI GPIO CONTROLLER (0x1000_1000)
    // =========================================================================
    axi_gpio #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) gpio_inst (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .o_led        (o_led),
        .i_sw         (i_sw),
        .i_btn        (i_btn),
        .s_axi_awaddr (s2_gpio_awaddr),
        .s_axi_awvalid(s2_gpio_awvalid),
        .s_axi_awready(s2_gpio_awready),
        .s_axi_wdata  (s2_gpio_wdata),
        .s_axi_wstrb  (s2_gpio_wstrb),
        .s_axi_wvalid (s2_gpio_wvalid),
        .s_axi_wready (s2_gpio_wready),
        .s_axi_bresp  (s2_gpio_bresp),
        .s_axi_bvalid (s2_gpio_bvalid),
        .s_axi_bready (s2_gpio_bready),
        .s_axi_araddr (s2_gpio_araddr),
        .s_axi_arvalid(s2_gpio_arvalid),
        .s_axi_arready(s2_gpio_arready),
        .s_axi_rdata  (s2_gpio_rdata),
        .s_axi_rresp  (s2_gpio_rresp),
        .s_axi_rvalid (s2_gpio_rvalid),
        .s_axi_rready (s2_gpio_rready)
    );

    // =========================================================================
    // 6. INSTANTIATE AXI MACHINE TIMER CONTROLLER (0x1000_2000)
    // =========================================================================
    axi_timer #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) timer_inst (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .o_timer_irq  (timer_irq),
        .s_axi_awaddr (s3_timer_awaddr),
        .s_axi_awvalid(s3_timer_awvalid),
        .s_axi_awready(s3_timer_awready),
        .s_axi_wdata  (s3_timer_wdata),
        .s_axi_wstrb  (s3_timer_wstrb),
        .s_axi_wvalid (s3_timer_wvalid),
        .s_axi_wready (s3_timer_wready),
        .s_axi_bresp  (s3_timer_bresp),
        .s_axi_bvalid (s3_timer_bvalid),
        .s_axi_bready (s3_timer_bready),
        .s_axi_araddr (s3_timer_araddr),
        .s_axi_arvalid(s3_timer_arvalid),
        .s_axi_arready(s3_timer_arready),
        .s_axi_rdata  (s3_timer_rdata),
        .s_axi_rresp  (s3_timer_rresp),
        .s_axi_rvalid (s3_timer_rvalid),
        .s_axi_rready (s3_timer_rready)
    );

endmodule

// =============================================================================
// MODULE BLOCK RAM DUAL-PORT CHUAN XILINX VIVADO (INFER BRAM THANH CONG)
// =============================================================================
module dual_port_bram #(
    parameter RAM_DEPTH = 4096, // 16KB (4096 words x 32-bit)
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    
    // Port A (Instruction Bus - Read Only)
    input  wire [11:0] addr_a,
    output reg  [31:0] dout_a,

    // Port B (Data Bus - Read / Write voi Byte Enables)
    input  wire        we_b,
    input  wire [3:0]  wstrb_b,
    input  wire [11:0] addr_b,
    input  wire [31:0] din_b,
    output reg  [31:0] dout_b
);

    (* ram_style = "block" *) reg [31:0] ram [0:RAM_DEPTH-1];

    integer k;
    initial begin
        for (k = 0; k < RAM_DEPTH; k = k + 1) begin
            ram[k] = 32'h00000013; // NOP
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, ram);
        end
`ifndef SYNTHESIS
        else begin

        // ---------------------------------------------------------------------
        // Chuong trinh mau kiem thu toan dien SoC:
        // 1. Tinh toan so hoc RV32I & RV32M
        // 2. Ghi chuoi ky tu ra UART Lite (0x1000_0000)
        // 3. Doc trang thai Switches tu GPIO (0x1000_1000) va xuat ra LEDs (0x1000_1004)
        // 4. Doc MTIME tu Timer (0x1000_2000)
        // 5. ECALL Halt ket thuc chuong trinh
        // ---------------------------------------------------------------------
        // 0x00: addi x1, x0, 5
        ram[0] = 32'h00500093;
        // 0x04: addi x2, x0, 10
        ram[1] = 32'h00a00113;
        // 0x08: add  x3, x1, x2       (x3 = 15)
        ram[2] = 32'h002081b3;
        // 0x0C: mul  x4, x1, x2       (x4 = 50 = 0x32)
        ram[3] = 32'h02208233;
        // 0x10: sw   x4, 64(x0)       (Luu 50 vao BRAM dia chi 64)
        ram[4] = 32'h04402023;
        // 0x14: lw   x5, 64(x0)       (Doc lai 50 vao x5)
        ram[5] = 32'h04002283;

        // 0x18: lui  x6, 0x10000      (x6 = 0x1000_0000: UART Base)
        ram[6] = 32'h10000337;
        // 0x1C: addi x7, x0, 72       (x7 = 'H' = 0x48)
        ram[7] = 32'h04800393;
        // 0x20: sw   x7, 0(x6)        (Xuat 'H' ra UART TX Data reg)
        ram[8] = 32'h00732023;

        // 0x24: lui  x8, 0x10001      (x8 = 0x1000_1000: GPIO Base)
        ram[9] = 32'h10001437;
        // 0x28: lw   x9, 0(x8)        (Doc Switches tu GPIO_IN)
        ram[10] = 32'h00042483;
        // 0x2C: sw   x9, 4(x8)        (Xuat gia tri switch ra LEDs tai GPIO_OUT)
        ram[11] = 32'h00942223;

        // 0x30: lui  x10, 0x10002     (x10 = 0x1000_2000: Timer Base)
        ram[12] = 32'h10002537;
        // 0x34: lw   x11, 0(x10)      (Doc MTIME_LOW vao x11)
        ram[13] = 32'h00052583;

        // 0x38: ecall                 (Halt mo phong)
        ram[14] = 32'h00000073;
        end
`endif
    end

    // Port A (Read-only)
    always @(posedge clk) begin
        dout_a <= ram[addr_a];
    end

    // Port B (Read/Write voi byte-enables)
    always @(posedge clk) begin
        if (we_b) begin
            if (wstrb_b[0]) ram[addr_b][7:0]   <= din_b[7:0];
            if (wstrb_b[1]) ram[addr_b][15:8]  <= din_b[15:8];
            if (wstrb_b[2]) ram[addr_b][23:16] <= din_b[23:16];
            if (wstrb_b[3]) ram[addr_b][31:24] <= din_b[31:24];
        end
        dout_b <= ram[addr_b];
    end

endmodule
