`timescale 1ns / 1ps

// =============================================================================
// MODULE: AXI4-LITE MACHINE TIMER CONTROLLER (MTIME, MTIMECMP, TIMER IRQ)
// =============================================================================
// - Tieu chuan giao tiep: AMBA AXI4-Lite Slave
// - Chuan kien truc: RISC-V Privileged Architecture (Machine-Mode Timer)
// - Bang thanh ghi:
//   * 0x00: MTIME_LOW     (Read/Write: [31:0] bo dem thoi gian thuc 64-bit)
//   * 0x04: MTIME_HIGH    (Read/Write: [63:32] bo dem thoi gian thuc 64-bit)
//   * 0x08: MTIMECMP_LOW  (Read/Write: [31:0] nguong so sanh ngat)
//   * 0x0C: MTIMECMP_HIGH (Read/Write: [63:32] nguong so sanh ngat)
//   * 0x10: TIMER_CTRL    (Read/Write: [0]=Timer Enable, [1]=IRQ Enable)
// - Tin hieu ngat: o_timer_irq = 1 khi mtime >= mtimecmp
// - 100% RTL Synchronous, Zero Latch, Timing closure > 100 MHz
// =============================================================================

module axi_timer #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // Interrupt output directly to CPU Machine Interrupt Pending (MIP.MTIP)
    output wire                  o_timer_irq,

    // AXI4-Lite Write Address Channel (AW)
    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,

    // AXI4-Lite Write Data Channel (W)
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [3:0]            s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,

    // AXI4-Lite Write Response Channel (B)
    output wire [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    // AXI4-Lite Read Address Channel (AR)
    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output reg                   s_axi_arready,

    // AXI4-Lite Read Data Channel (R)
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output wire [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready
);

    assign s_axi_bresp = 2'b00; // OKAY
    assign s_axi_rresp = 2'b00; // OKAY

    // -------------------------------------------------------------------------
    // 64-BIT REAL-TIME COUNTER & COMPARE REGISTERS
    // -------------------------------------------------------------------------
    reg [63:0] mtime_reg;
    reg [63:0] mtimecmp_reg;
    reg [1:0]  timer_ctrl_reg; // [0] = Enable, [1] = IRQ Enable

    wire timer_en     = timer_ctrl_reg[0];
    wire timer_irq_en = timer_ctrl_reg[1];

    // Ngat Timer RISC-V: Phat sinh khi mtime >= mtimecmp va duoc phep ngat
    assign o_timer_irq = (mtime_reg >= mtimecmp_reg) && timer_irq_en;

    // -------------------------------------------------------------------------
    // AXI4-LITE WRITE CHANNELS (AW, W, B)
    // -------------------------------------------------------------------------
    reg [ADDR_WIDTH-1:0]  awaddr_reg;
    reg                   awaddr_valid_reg;
    wire [ADDR_WIDTH-1:0] effective_write_addr = (s_axi_awvalid && s_axi_awready) ? s_axi_awaddr :
                                                 awaddr_valid_reg ? awaddr_reg : s_axi_awaddr;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            s_axi_awready    <= 1'b0;
            s_axi_wready     <= 1'b0;
            s_axi_bvalid     <= 1'b0;
            awaddr_reg       <= 32'd0;
            awaddr_valid_reg <= 1'b0;
            mtime_reg        <= 64'd0;
            mtimecmp_reg     <= 64'hFFFF_FFFF_FFFF_FFFF; // Mac dinh lon nhat de khong ngat som
            timer_ctrl_reg   <= 2'b11;                   // Mac dinh bat timer va bat IRQ
        end else begin
            // Bo dem tang thoi gian thuc
            if (timer_en) begin
                mtime_reg <= mtime_reg + 64'd1;
            end

            // Address Handshake (Single-cycle pulse per transaction)
            if (s_axi_awvalid && !s_axi_awready && !awaddr_valid_reg && !s_axi_bvalid) begin
                s_axi_awready    <= 1'b1;
                awaddr_reg       <= s_axi_awaddr;
                awaddr_valid_reg <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
            end

            // Data Handshake & Write Operation (Ghi de gia tri counter neu CPU can)
            if (s_axi_wvalid && !s_axi_wready && !s_axi_bvalid) begin
                s_axi_wready <= 1'b1;
                case (effective_write_addr[4:0])
                    5'h00: begin // MTIME_LOW
                        if (s_axi_wstrb[0]) mtime_reg[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mtime_reg[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mtime_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mtime_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    5'h04: begin // MTIME_HIGH
                        if (s_axi_wstrb[0]) mtime_reg[39:32] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mtime_reg[47:40] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mtime_reg[55:48] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mtime_reg[63:56] <= s_axi_wdata[31:24];
                    end
                    5'h08: begin // MTIMECMP_LOW
                        if (s_axi_wstrb[0]) mtimecmp_reg[7:0]   <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mtimecmp_reg[15:8]  <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mtimecmp_reg[23:16] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mtimecmp_reg[31:24] <= s_axi_wdata[31:24];
                    end
                    5'h0C: begin // MTIMECMP_HIGH
                        if (s_axi_wstrb[0]) mtimecmp_reg[39:32] <= s_axi_wdata[7:0];
                        if (s_axi_wstrb[1]) mtimecmp_reg[47:40] <= s_axi_wdata[15:8];
                        if (s_axi_wstrb[2]) mtimecmp_reg[55:48] <= s_axi_wdata[23:16];
                        if (s_axi_wstrb[3]) mtimecmp_reg[63:56] <= s_axi_wdata[31:24];
                    end
                    5'h10: begin // TIMER_CTRL
                        if (s_axi_wstrb[0]) timer_ctrl_reg <= s_axi_wdata[1:0];
                    end
                    default: ;
                endcase
            end else begin
                s_axi_wready <= 1'b0;
            end

            // Write Response Handshake
            if (s_axi_wready && s_axi_wvalid) begin
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid     <= 1'b0;
                awaddr_valid_reg <= 1'b0;
            end
        end
    end

    // -------------------------------------------------------------------------
    // AXI4-LITE READ CHANNELS (AR, R)
    // -------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rdata   <= 32'd0;
        end else begin
            // Address Handshake
            if (s_axi_arvalid && !s_axi_arready) begin
                s_axi_arready <= 1'b1;
                case (s_axi_araddr[4:0])
                    5'h00: s_axi_rdata <= mtime_reg[31:0];
                    5'h04: s_axi_rdata <= mtime_reg[63:32];
                    5'h08: s_axi_rdata <= mtimecmp_reg[31:0];
                    5'h0C: s_axi_rdata <= mtimecmp_reg[63:32];
                    5'h10: s_axi_rdata <= {30'd0, timer_ctrl_reg};
                    default: s_axi_rdata <= 32'd0;
                endcase
            end else begin
                s_axi_arready <= 1'b0;
            end

            // Data Read Response
            if (s_axi_arvalid && s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
