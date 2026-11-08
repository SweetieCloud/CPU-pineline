`timescale 1ns / 1ps

// =============================================================================
// MODULE: AXI4-LITE CROSSBAR INTERCONNECT (2 MASTERS x 4 SLAVES + DECERR)
// =============================================================================
// - Masters:
//   * Master 0 (M0): CPU I-Cache Controller (Read-Only)
//   * Master 1 (M1): CPU D-Bus Controller (Read / Write)
// - Slaves:
//   * Slave 0 (S0): Dual-Port BRAM (0x0000_0000 - 0x0000_3FFF, 16KB)
//                   Port A: Dedicated to M0 (I-Cache) -> Zero Bus Contention!
//                   Port B: Connected to M1 (D-Bus)
//   * Slave 1 (S1): AXI UART Lite Controller (0x1000_0000 - 0x1000_0FFF)
//   * Slave 2 (S2): AXI GPIO Controller      (0x1000_1000 - 0x1000_1FFF)
//   * Slave 3 (S3): AXI Timer / MTIME        (0x1000_2000 - 0x1000_2FFF)
//   * Internal DECERR: Phat ma phan hoi DECERR (2'b11) khi truy cap dia chi sai
// - Tieu chuan: AMBA AXI4-Lite, Handshake doc lap, Zero Latch
// =============================================================================

module axi_interconnect #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // =========================================================================
    // MASTER 0: CPU I-CACHE INTERFACE (READ ONLY)
    // =========================================================================
    input  wire [ADDR_WIDTH-1:0] m0_axi_araddr,
    input  wire                  m0_axi_arvalid,
    output wire                  m0_axi_arready,
    output wire [DATA_WIDTH-1:0] m0_axi_rdata,
    output wire [1:0]            m0_axi_rresp,
    output wire                  m0_axi_rvalid,
    input  wire                  m0_axi_rready,

    // =========================================================================
    // MASTER 1: CPU D-BUS INTERFACE (READ / WRITE)
    // =========================================================================
    // Write Address Channel (AW)
    input  wire [ADDR_WIDTH-1:0] m1_axi_awaddr,
    input  wire                  m1_axi_awvalid,
    output wire                  m1_axi_awready,

    // Write Data Channel (W)
    input  wire [DATA_WIDTH-1:0] m1_axi_wdata,
    input  wire [3:0]            m1_axi_wstrb,
    input  wire                  m1_axi_wvalid,
    output wire                  m1_axi_wready,

    // Write Response Channel (B)
    output wire [1:0]            m1_axi_bresp,
    output wire                  m1_axi_bvalid,
    input  wire                  m1_axi_bready,

    // Read Address Channel (AR)
    input  wire [ADDR_WIDTH-1:0] m1_axi_araddr,
    input  wire                  m1_axi_arvalid,
    output wire                  m1_axi_arready,

    // Read Data Channel (R)
    output wire [DATA_WIDTH-1:0] m1_axi_rdata,
    output wire [1:0]            m1_axi_rresp,
    output wire                  m1_axi_rvalid,
    input  wire                  m1_axi_rready,

    // =========================================================================
    // SLAVE 0: BRAM (DUAL PORT - PORT A FOR M0, PORT B FOR M1)
    // =========================================================================
    // Port A (Read-only for M0)
    output wire [ADDR_WIDTH-1:0] s0_bram_araddr_a,
    output wire                  s0_bram_arvalid_a,
    input  wire                  s0_bram_arready_a,
    input  wire [DATA_WIDTH-1:0] s0_bram_rdata_a,
    input  wire [1:0]            s0_bram_rresp_a,
    input  wire                  s0_bram_rvalid_a,
    output wire                  s0_bram_rready_a,

    // Port B (Read/Write for M1)
    output wire [ADDR_WIDTH-1:0] s0_bram_awaddr_b,
    output wire                  s0_bram_awvalid_b,
    input  wire                  s0_bram_awready_b,
    output wire [DATA_WIDTH-1:0] s0_bram_wdata_b,
    output wire [3:0]            s0_bram_wstrb_b,
    output wire                  s0_bram_wvalid_b,
    input  wire                  s0_bram_wready_b,
    input  wire [1:0]            s0_bram_bresp_b,
    input  wire                  s0_bram_bvalid_b,
    output wire                  s0_bram_bready_b,
    output wire [ADDR_WIDTH-1:0] s0_bram_araddr_b,
    output wire                  s0_bram_arvalid_b,
    input  wire                  s0_bram_arready_b,
    input  wire [DATA_WIDTH-1:0] s0_bram_rdata_b,
    input  wire [1:0]            s0_bram_rresp_b,
    input  wire                  s0_bram_rvalid_b,
    output wire                  s0_bram_rready_b,

    // =========================================================================
    // SLAVE 1: UART LITE CONTROLLER (0x1000_0000 - 0x1000_0FFF)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] s1_uart_awaddr,
    output wire                  s1_uart_awvalid,
    input  wire                  s1_uart_awready,
    output wire [DATA_WIDTH-1:0] s1_uart_wdata,
    output wire [3:0]            s1_uart_wstrb,
    output wire                  s1_uart_wvalid,
    input  wire                  s1_uart_wready,
    input  wire [1:0]            s1_uart_bresp,
    input  wire                  s1_uart_bvalid,
    output wire                  s1_uart_bready,
    output wire [ADDR_WIDTH-1:0] s1_uart_araddr,
    output wire                  s1_uart_arvalid,
    input  wire                  s1_uart_arready,
    input  wire [DATA_WIDTH-1:0] s1_uart_rdata,
    input  wire [1:0]            s1_uart_rresp,
    input  wire                  s1_uart_rvalid,
    output wire                  s1_uart_rready,

    // =========================================================================
    // SLAVE 2: GPIO CONTROLLER (0x1000_1000 - 0x1000_1FFF)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] s2_gpio_awaddr,
    output wire                  s2_gpio_awvalid,
    input  wire                  s2_gpio_awready,
    output wire [DATA_WIDTH-1:0] s2_gpio_wdata,
    output wire [3:0]            s2_gpio_wstrb,
    output wire                  s2_gpio_wvalid,
    input  wire                  s2_gpio_wready,
    input  wire [1:0]            s2_gpio_bresp,
    input  wire                  s2_gpio_bvalid,
    output wire                  s2_gpio_bready,
    output wire [ADDR_WIDTH-1:0] s2_gpio_araddr,
    output wire                  s2_gpio_arvalid,
    input  wire                  s2_gpio_arready,
    input  wire [DATA_WIDTH-1:0] s2_gpio_rdata,
    input  wire [1:0]            s2_gpio_rresp,
    input  wire                  s2_gpio_rvalid,
    output wire                  s2_gpio_rready,

    // =========================================================================
    // SLAVE 3: TIMER / MTIME CONTROLLER (0x1000_2000 - 0x1000_2FFF)
    // =========================================================================
    output wire [ADDR_WIDTH-1:0] s3_timer_awaddr,
    output wire                  s3_timer_awvalid,
    input  wire                  s3_timer_awready,
    output wire [DATA_WIDTH-1:0] s3_timer_wdata,
    output wire [3:0]            s3_timer_wstrb,
    output wire                  s3_timer_wvalid,
    input  wire                  s3_timer_wready,
    input  wire [1:0]            s3_timer_bresp,
    input  wire                  s3_timer_bvalid,
    output wire                  s3_timer_bready,
    output wire [ADDR_WIDTH-1:0] s3_timer_araddr,
    output wire                  s3_timer_arvalid,
    input  wire                  s3_timer_arready,
    input  wire [DATA_WIDTH-1:0] s3_timer_rdata,
    input  wire [1:0]            s3_timer_rresp,
    input  wire                  s3_timer_rvalid,
    output wire                  s3_timer_rready
);

    // =========================================================================
    // 1. ROUTING MASTER 0 (I-CACHE) -> BRAM PORT A (DEDICATED ZERO CONTENTION)
    // =========================================================================
    assign s0_bram_araddr_a  = m0_axi_araddr;
    assign s0_bram_arvalid_a = m0_axi_arvalid;
    assign m0_axi_arready    = s0_bram_arready_a;
    assign m0_axi_rdata      = s0_bram_rdata_a;
    assign m0_axi_rresp      = s0_bram_rresp_a;
    assign m0_axi_rvalid     = s0_bram_rvalid_a;
    assign s0_bram_rready_a  = m0_axi_rready;

    // =========================================================================
    // 2. ADDRESS DECODING FOR MASTER 1 (D-BUS)
    // =========================================================================
    localparam SLAVE_BRAM  = 3'd0;
    localparam SLAVE_UART  = 3'd1;
    localparam SLAVE_GPIO  = 3'd2;
    localparam SLAVE_TIMER = 3'd3;
    localparam SLAVE_DECERR = 3'd4;

    function [2:0] decode_addr(input [ADDR_WIDTH-1:0] addr);
        begin
            if (addr[31:14] == 18'd0) begin
                decode_addr = SLAVE_BRAM; // 0x0000_0000 - 0x0000_3FFF (16KB)
            end else if (addr[31:12] == 20'h10000) begin
                decode_addr = SLAVE_UART;
            end else if (addr[31:12] == 20'h10001) begin
                decode_addr = SLAVE_GPIO;
            end else if (addr[31:12] == 20'h10002) begin
                decode_addr = SLAVE_TIMER;
            end else begin
                decode_addr = SLAVE_DECERR;
            end
        end
    endfunction

    wire [2:0] current_wr_slave = decode_addr(m1_axi_awaddr);
    wire [2:0] current_rd_slave = decode_addr(m1_axi_araddr);

    // =========================================================================
    // 3. MASTER 1 WRITE CHANNELS (AW, W, B) DEMUX & MUX
    // =========================================================================
    reg [2:0] wr_target_slave;
    reg       wr_active;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            wr_target_slave <= SLAVE_BRAM;
            wr_active       <= 1'b0;
        end else begin
            if (m1_axi_bvalid && m1_axi_bready) begin
                wr_active       <= 1'b0;
            end else if (m1_axi_awvalid && m1_axi_awready && !wr_active) begin
                wr_target_slave <= current_wr_slave;
                wr_active       <= 1'b1;
            end
        end
    end

    wire [2:0] active_wr_slave = wr_active ? wr_target_slave : current_wr_slave;

    // Broadcast write data and addresses to all slaves
    assign s0_bram_awaddr_b = m1_axi_awaddr;
    assign s0_bram_wdata_b  = m1_axi_wdata;
    assign s0_bram_wstrb_b  = m1_axi_wstrb;

    assign s1_uart_awaddr   = m1_axi_awaddr;
    assign s1_uart_wdata    = m1_axi_wdata;
    assign s1_uart_wstrb    = m1_axi_wstrb;

    assign s2_gpio_awaddr   = m1_axi_awaddr;
    assign s2_gpio_wdata    = m1_axi_wdata;
    assign s2_gpio_wstrb    = m1_axi_wstrb;

    assign s3_timer_awaddr  = m1_axi_awaddr;
    assign s3_timer_wdata   = m1_axi_wdata;
    assign s3_timer_wstrb   = m1_axi_wstrb;

    // Route AWVALID to target slave
    assign s0_bram_awvalid_b = (active_wr_slave == SLAVE_BRAM)  ? m1_axi_awvalid : 1'b0;
    assign s1_uart_awvalid   = (active_wr_slave == SLAVE_UART)  ? m1_axi_awvalid : 1'b0;
    assign s2_gpio_awvalid   = (active_wr_slave == SLAVE_GPIO)  ? m1_axi_awvalid : 1'b0;
    assign s3_timer_awvalid  = (active_wr_slave == SLAVE_TIMER) ? m1_axi_awvalid : 1'b0;

    // Route WVALID to target slave (chi dinh tuyen khi dia chi AW hop le hoac giao dich ghi da bat dau)
    wire wr_addr_valid = m1_axi_awvalid || wr_active;

    assign s0_bram_wvalid_b  = wr_addr_valid && (active_wr_slave == SLAVE_BRAM)  ? m1_axi_wvalid : 1'b0;
    assign s1_uart_wvalid    = wr_addr_valid && (active_wr_slave == SLAVE_UART)  ? m1_axi_wvalid : 1'b0;
    assign s2_gpio_wvalid    = wr_addr_valid && (active_wr_slave == SLAVE_GPIO)  ? m1_axi_wvalid : 1'b0;
    assign s3_timer_wvalid   = wr_addr_valid && (active_wr_slave == SLAVE_TIMER) ? m1_axi_wvalid : 1'b0;

    // Route BREADY to target slave
    assign s0_bram_bready_b  = (active_wr_slave == SLAVE_BRAM)  ? m1_axi_bready : 1'b0;
    assign s1_uart_bready    = (active_wr_slave == SLAVE_UART)  ? m1_axi_bready : 1'b0;
    assign s2_gpio_bready    = (active_wr_slave == SLAVE_GPIO)  ? m1_axi_bready : 1'b0;
    assign s3_timer_bready   = (active_wr_slave == SLAVE_TIMER) ? m1_axi_bready : 1'b0;

    // DECERR Write Handler Logic (1-cycle registered ready/valid handshake)
    reg decerr_awready_reg;
    reg decerr_wready_reg;
    reg decerr_bvalid_reg;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            decerr_awready_reg <= 1'b0;
            decerr_wready_reg  <= 1'b0;
            decerr_bvalid_reg  <= 1'b0;
        end else begin
            decerr_awready_reg <= (active_wr_slave == SLAVE_DECERR) && m1_axi_awvalid && !decerr_awready_reg && !decerr_bvalid_reg;
            decerr_wready_reg  <= (active_wr_slave == SLAVE_DECERR) && m1_axi_wvalid  && !decerr_wready_reg  && !decerr_bvalid_reg;

            if (active_wr_slave == SLAVE_DECERR && m1_axi_awvalid && m1_axi_wvalid && decerr_awready_reg && decerr_wready_reg) begin
                decerr_bvalid_reg <= 1'b1;
            end else if (decerr_bvalid_reg && m1_axi_bready) begin
                decerr_bvalid_reg <= 1'b0;
            end
        end
    end

    // Multiplex write responses back to Master 1
    assign m1_axi_awready = (active_wr_slave == SLAVE_BRAM)  ? s0_bram_awready_b :
                            (active_wr_slave == SLAVE_UART)  ? s1_uart_awready   :
                            (active_wr_slave == SLAVE_GPIO)  ? s2_gpio_awready   :
                            (active_wr_slave == SLAVE_TIMER) ? s3_timer_awready  :
                            decerr_awready_reg;

    assign m1_axi_wready  = wr_addr_valid ?
                           ((active_wr_slave == SLAVE_BRAM)  ? s0_bram_wready_b  :
                            (active_wr_slave == SLAVE_UART)  ? s1_uart_wready    :
                            (active_wr_slave == SLAVE_GPIO)  ? s2_gpio_wready    :
                            (active_wr_slave == SLAVE_TIMER) ? s3_timer_wready   :
                            decerr_wready_reg) : 1'b0;

    assign m1_axi_bvalid  = (active_wr_slave == SLAVE_BRAM)  ? s0_bram_bvalid_b  :
                            (active_wr_slave == SLAVE_UART)  ? s1_uart_bvalid    :
                            (active_wr_slave == SLAVE_GPIO)  ? s2_gpio_bvalid    :
                            (active_wr_slave == SLAVE_TIMER) ? s3_timer_bvalid   :
                            decerr_bvalid_reg;

    assign m1_axi_bresp   = (active_wr_slave == SLAVE_BRAM)  ? s0_bram_bresp_b   :
                            (active_wr_slave == SLAVE_UART)  ? s1_uart_bresp     :
                            (active_wr_slave == SLAVE_GPIO)  ? s2_gpio_bresp     :
                            (active_wr_slave == SLAVE_TIMER) ? s3_timer_bresp    :
                            2'b11; // DECERR = 2'b11

    // =========================================================================
    // 4. MASTER 1 READ CHANNELS (AR, R) DEMUX & MUX
    // =========================================================================
    reg [2:0] rd_target_slave;
    reg       rd_active;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            rd_target_slave <= SLAVE_BRAM;
            rd_active       <= 1'b0;
        end else begin
            if (m1_axi_rvalid && m1_axi_rready) begin
                rd_active       <= 1'b0;
            end else if (m1_axi_arvalid && m1_axi_arready && !rd_active) begin
                rd_target_slave <= current_rd_slave;
                rd_active       <= 1'b1;
            end
        end
    end

    wire [2:0] active_rd_slave = rd_active ? rd_target_slave : current_rd_slave;

    // Broadcast read address to all slaves
    assign s0_bram_araddr_b = m1_axi_araddr;
    assign s1_uart_araddr   = m1_axi_araddr;
    assign s2_gpio_araddr   = m1_axi_araddr;
    assign s3_timer_araddr  = m1_axi_araddr;

    // Route ARVALID to target slave
    assign s0_bram_arvalid_b = (active_rd_slave == SLAVE_BRAM)  ? m1_axi_arvalid : 1'b0;
    assign s1_uart_arvalid   = (active_rd_slave == SLAVE_UART)  ? m1_axi_arvalid : 1'b0;
    assign s2_gpio_arvalid   = (active_rd_slave == SLAVE_GPIO)  ? m1_axi_arvalid : 1'b0;
    assign s3_timer_arvalid  = (active_rd_slave == SLAVE_TIMER) ? m1_axi_arvalid : 1'b0;

    // Route RREADY to target slave
    assign s0_bram_rready_b  = (active_rd_slave == SLAVE_BRAM)  ? m1_axi_rready  : 1'b0;
    assign s1_uart_rready    = (active_rd_slave == SLAVE_UART)  ? m1_axi_rready  : 1'b0;
    assign s2_gpio_rready    = (active_rd_slave == SLAVE_GPIO)  ? m1_axi_rready  : 1'b0;
    assign s3_timer_rready   = (active_rd_slave == SLAVE_TIMER) ? m1_axi_rready  : 1'b0;

    // DECERR Read Handler Logic (1-cycle registered ready/valid handshake)
    reg decerr_arready_reg;
    reg decerr_rvalid_reg;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            decerr_arready_reg <= 1'b0;
            decerr_rvalid_reg  <= 1'b0;
        end else begin
            decerr_arready_reg <= (active_rd_slave == SLAVE_DECERR) && m1_axi_arvalid && !decerr_arready_reg && !decerr_rvalid_reg;

            if (active_rd_slave == SLAVE_DECERR && m1_axi_arvalid && decerr_arready_reg) begin
                decerr_rvalid_reg <= 1'b1;
            end else if (decerr_rvalid_reg && m1_axi_rready) begin
                decerr_rvalid_reg <= 1'b0;
            end
        end
    end

    // Multiplex read responses back to Master 1
    assign m1_axi_arready = (active_rd_slave == SLAVE_BRAM)  ? s0_bram_arready_b :
                            (active_rd_slave == SLAVE_UART)  ? s1_uart_arready   :
                            (active_rd_slave == SLAVE_GPIO)  ? s2_gpio_arready   :
                            (active_rd_slave == SLAVE_TIMER) ? s3_timer_arready  :
                            decerr_arready_reg;

    assign m1_axi_rvalid  = (active_rd_slave == SLAVE_BRAM)  ? s0_bram_rvalid_b  :
                            (active_rd_slave == SLAVE_UART)  ? s1_uart_rvalid    :
                            (active_rd_slave == SLAVE_GPIO)  ? s2_gpio_rvalid    :
                            (active_rd_slave == SLAVE_TIMER) ? s3_timer_rvalid   :
                            decerr_rvalid_reg;

    assign m1_axi_rresp   = (active_rd_slave == SLAVE_BRAM)  ? s0_bram_rresp_b   :
                            (active_rd_slave == SLAVE_UART)  ? s1_uart_rresp     :
                            (active_rd_slave == SLAVE_GPIO)  ? s2_gpio_rresp     :
                            (active_rd_slave == SLAVE_TIMER) ? s3_timer_rresp    :
                            2'b11; // DECERR = 2'b11

    assign m1_axi_rdata   = (active_rd_slave == SLAVE_BRAM)  ? s0_bram_rdata_b   :
                            (active_rd_slave == SLAVE_UART)  ? s1_uart_rdata     :
                            (active_rd_slave == SLAVE_GPIO)  ? s2_gpio_rdata     :
                            (active_rd_slave == SLAVE_TIMER) ? s3_timer_rdata    :
                            32'hDEADBEEF;

endmodule
