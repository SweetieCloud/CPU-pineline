`timescale 1ns / 1ps

module cpu_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // =========================================================================
    // AXI4-LITE INSTRUCTION BUS (I-BUS) MASTER INTERFACE (READ ONLY)
    // =========================================================================
    // Read Address Channel (AR)
    output wire [ADDR_WIDTH-1:0] o_axi_i_araddr,
    output wire                  o_axi_i_arvalid,
    input  wire                  i_axi_i_arready,
    output wire [2:0]            o_axi_i_prot,

    // Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0] i_axi_i_rdata,
    input  wire [1:0]            i_axi_i_rresp,
    input  wire                  i_axi_i_rvalid,
    output wire                  o_axi_i_rready,

    // =========================================================================
    // AXI4-LITE DATA BUS (D-BUS) MASTER INTERFACE (READ/WRITE)
    // =========================================================================
    // Write Address Channel (AW)
    output wire [ADDR_WIDTH-1:0] o_axi_d_awaddr,
    output wire                  o_axi_d_awvalid,
    input  wire                  i_axi_d_awready,

    // Write Data Channel (W)
    output wire [DATA_WIDTH-1:0] o_axi_d_wdata,
    output wire [3:0]            o_axi_d_wstrb,
    output wire                  o_axi_d_wvalid,
    input  wire                  i_axi_d_wready,

    // Write Response Channel (B)
    input  wire [1:0]            i_axi_d_bresp,
    input  wire                  i_axi_d_bvalid,
    output wire                  o_axi_d_bready,

    // Read Address Channel (AR)
    output wire [ADDR_WIDTH-1:0] o_axi_d_araddr,
    output wire                  o_axi_d_arvalid,
    input  wire                  i_axi_d_arready,

    // Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0] i_axi_d_rdata,
    input  wire [1:0]            i_axi_d_rresp,
    input  wire                  i_axi_d_rvalid,
    output wire                  o_axi_d_rready,

    // Interrupt Inputs
    input  wire                  i_timer_irq,
    input  wire                  i_external_irq,

    // Status / Debug Outputs
    output wire                  o_ecall_halt
);

    // -------------------------------------------------------------------------
    // INTERNAL WIRES BETWEEN DATAPATH, ICACHE, AND AXI MASTERS
    // -------------------------------------------------------------------------
    // Internal Instruction Bus Signals (IF Stage)
    wire [ADDR_WIDTH-1:0] dp_imem_addr;
    wire                  dp_imem_req;
    wire                  dp_imem_flush;
    wire                  dp_icache_invalidate;
    wire [DATA_WIDTH-1:0] dp_imem_rdata;
    wire                  dp_imem_valid;
    wire                  axi_i_stall;

    // Internal Data Bus Signals (MEM Stage)
    wire [ADDR_WIDTH-1:0] dp_dmem_addr;
    wire [DATA_WIDTH-1:0] dp_dmem_wdata;
    wire [2:0]            dp_dmem_funct3;
    wire                  dp_dmem_req_read;
    wire                  dp_dmem_req_write;
    wire [DATA_WIDTH-1:0] dp_dmem_rdata;
    wire                  axi_d_stall;

    // -------------------------------------------------------------------------
    // 1. INSTANTIATE CORE DATAPATH 32-BIT
    // -------------------------------------------------------------------------
    datapath #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) datapath_inst (
        .i_clk               (i_clk),
        .i_rst_n             (i_rst_n),

        // Instruction Bus Interface (IF Stage)
        .o_imem_addr         (dp_imem_addr),
        .o_imem_req          (dp_imem_req),
        .o_imem_flush        (dp_imem_flush),
        .o_icache_invalidate (dp_icache_invalidate),
        .i_imem_rdata        (dp_imem_rdata),
        .i_imem_valid        (dp_imem_valid),
        .i_axi_i_stall       (axi_i_stall),

        // Data Bus Interface (MEM Stage)
        .o_dmem_addr         (dp_dmem_addr),
        .o_dmem_wdata        (dp_dmem_wdata),
        .o_dmem_funct3       (dp_dmem_funct3),
        .o_dmem_req_read     (dp_dmem_req_read),
        .o_dmem_req_write    (dp_dmem_req_write),
        .i_dmem_rdata        (dp_dmem_rdata),
        .i_axi_d_stall       (axi_d_stall),

        // Interrupts
        .i_timer_irq         (i_timer_irq),
        .i_external_irq      (i_external_irq),

        // Debug & Control
        .o_ecall_halt        (o_ecall_halt)
    );

    // -------------------------------------------------------------------------
    // 2. INSTANTIATE L1 INSTRUCTION CACHE CONTROLLER (ICACHE)
    // -------------------------------------------------------------------------
    // Direct-Mapped 1024 Bytes (64 lines x 16 Bytes/line)
    // Cung cap do tre 1 chu ky (0 wait-states) khi Hit, tu dong refill qua AXI khi Miss
    icache #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .LINE_WORDS(4),
        .NUM_LINES (64)
    ) icache_inst (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),

        // CPU Pipeline IF Interface
        .i_req           (dp_imem_req),
        .i_addr          (dp_imem_addr),
        .i_pipeline_hold (axi_d_stall),
        .i_flush         (dp_imem_flush),
        .i_invalidate    (dp_icache_invalidate),
        .o_rdata         (dp_imem_rdata),
        .o_valid         (dp_imem_valid),
        .o_stall         (axi_i_stall),
        .o_hit           (),

        // AXI4-Lite Refill Master Interface Ports
        .o_axi_araddr    (o_axi_i_araddr),
        .o_axi_arvalid   (o_axi_i_arvalid),
        .i_axi_arready   (i_axi_i_arready),
        .o_axi_prot      (o_axi_i_prot),
        .i_axi_rdata     (i_axi_i_rdata),
        .i_axi_rresp     (i_axi_i_rresp),
        .i_axi_rvalid    (i_axi_i_rvalid),
        .o_axi_rready    (o_axi_i_rready)
    );

    // -------------------------------------------------------------------------
    // 3. INSTANTIATE AXI4-LITE DATA MASTER CONTROLLER (D-BUS)
    // -------------------------------------------------------------------------
    axi_lite_master_d #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) axi_d_master_inst (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),

        // CPU Pipeline MEM Interface
        .i_req_read      (dp_dmem_req_read),
        .i_req_write     (dp_dmem_req_write),
        .i_addr          (dp_dmem_addr),
        .i_wdata         (dp_dmem_wdata),
        .i_funct3        (dp_dmem_funct3),
        .i_pipeline_hold (axi_i_stall),
        .o_rdata         (dp_dmem_rdata),
        .o_stall         (axi_d_stall),

        // AXI4-Lite Interface Ports
        .o_axi_awaddr    (o_axi_d_awaddr),
        .o_axi_awvalid   (o_axi_d_awvalid),
        .i_axi_awready   (i_axi_d_awready),
        .o_axi_wdata     (o_axi_d_wdata),
        .o_axi_wstrb     (o_axi_d_wstrb),
        .o_axi_wvalid    (o_axi_d_wvalid),
        .i_axi_wready    (i_axi_d_wready),
        .i_axi_bresp     (i_axi_d_bresp),
        .i_axi_bvalid    (i_axi_d_bvalid),
        .o_axi_bready    (o_axi_d_bready),
        .o_axi_araddr    (o_axi_d_araddr),
        .o_axi_arvalid   (o_axi_d_arvalid),
        .i_axi_arready   (i_axi_d_arready),
        .i_axi_rdata     (i_axi_d_rdata),
        .i_axi_rresp     (i_axi_d_rresp),
        .i_axi_rvalid    (i_axi_d_rvalid),
        .o_axi_rready    (o_axi_d_rready)
    );

endmodule
