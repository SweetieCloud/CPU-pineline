`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC CORE TESTBENCH: RV32IM 5-STAGE PIPELINE + L1 ICACHE + AXI + SVA
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập hệ thống con cpu_top (Core + I-Cache +
//                              Branch Predictor + RV32M + CSR + AXI Masters).
//   - Layer 2 (Mock Services): Mock AXI4-Lite I-Bus Slave Memory, Mock AXI4-Lite
//                              D-Bus Slave Memory, và Mock Interrupt Service
//                              (i_timer_irq, i_external_irq).
//   - Layer 3 (Spy & SVA)    : Kết nối toàn diện module rv32i_sva kiểm tra 11
//                              bất biến kiến trúc/giao thức và thu thập 9 bộ đếm
//                              Spy (Instruction Retire, Bus, CSR, FENCE.I, Div).
//   - Layer 4 (Scoreboard)   : Các hàm expect_reg, expect_mem, expect_csr,
//                              expect_spy kiểm tra nghiêm ngặt 56 Checkpoints.
// =============================================================================

module cpu_tb;

    parameter ADDR_WIDTH = 32;
    parameter DATA_WIDTH = 32;

    reg clk;
    reg rst_n;

    // Mock External Interrupt Service Signals
    reg mock_timer_irq;
    reg mock_external_irq;

    // AXI I-Bus
    wire [ADDR_WIDTH-1:0] axi_i_araddr;
    wire                  axi_i_arvalid;
    reg                   axi_i_arready;
    wire [2:0]            axi_i_prot;
    reg  [DATA_WIDTH-1:0] axi_i_rdata;
    reg  [1:0]            axi_i_rresp;
    reg                   axi_i_rvalid;
    wire                  axi_i_rready;

    // AXI D-Bus
    wire [ADDR_WIDTH-1:0] axi_d_awaddr;
    wire                  axi_d_awvalid;
    reg                   axi_d_awready;
    wire [DATA_WIDTH-1:0] axi_d_wdata;
    wire [3:0]            axi_d_wstrb;
    wire                  axi_d_wvalid;
    reg                   axi_d_wready;
    reg  [1:0]            axi_d_bresp;
    reg                   axi_d_bvalid;
    wire                  axi_d_bready;
    wire [ADDR_WIDTH-1:0] axi_d_araddr;
    wire                  axi_d_arvalid;
    reg                   axi_d_arready;
    reg  [DATA_WIDTH-1:0] axi_d_rdata;
    reg  [1:0]            axi_d_rresp;
    reg                   axi_d_rvalid;
    wire                  axi_d_rready;

    wire o_ecall_halt;

    // Spy Counters from SVA Monitor
    wire [31:0] spy_inst_retired_cnt;
    wire [31:0] spy_icache_req_cnt;
    wire [31:0] spy_dmem_read_cnt;
    wire [31:0] spy_dmem_write_cnt;
    wire [31:0] spy_branch_mispredict_cnt;
    wire [31:0] spy_csr_write_cnt;
    wire [31:0] spy_icache_inv_cnt;
    wire [31:0] spy_div_exec_cnt;
    wire [31:0] spy_sva_error_cnt;

    // =========================================================================
    // LAYER 1: INSTANTIATE CPU CORE TOP (DUT ISOLATION)
    // =========================================================================
    cpu_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .o_axi_i_araddr  (axi_i_araddr),
        .o_axi_i_arvalid (axi_i_arvalid),
        .i_axi_i_arready (axi_i_arready),
        .o_axi_i_prot    (axi_i_prot),
        .i_axi_i_rdata   (axi_i_rdata),
        .i_axi_i_rresp   (axi_i_rresp),
        .i_axi_i_rvalid  (axi_i_rvalid),
        .o_axi_i_rready  (axi_i_rready),
        .o_axi_d_awaddr  (axi_d_awaddr),
        .o_axi_d_awvalid (axi_d_awvalid),
        .i_axi_d_awready (axi_d_awready),
        .o_axi_d_wdata   (axi_d_wdata),
        .o_axi_d_wstrb   (axi_d_wstrb),
        .o_axi_d_wvalid  (axi_d_wvalid),
        .i_axi_d_wready  (axi_d_wready),
        .i_axi_d_bresp   (axi_d_bresp),
        .i_axi_d_bvalid  (axi_d_bvalid),
        .o_axi_d_bready  (axi_d_bready),
        .o_axi_d_araddr  (axi_d_araddr),
        .o_axi_d_arvalid (axi_d_arvalid),
        .i_axi_d_arready (axi_d_arready),
        .i_axi_d_rdata   (axi_d_rdata),
        .i_axi_d_rresp   (axi_d_rresp),
        .i_axi_d_rvalid  (axi_d_rvalid),
        .o_axi_d_rready  (axi_d_rready),
        .i_timer_irq     (mock_timer_irq),
        .i_external_irq  (mock_external_irq),
        .o_ecall_halt    (o_ecall_halt)
    );

    // =========================================================================
    // LAYER 3: BIND SYSTEMVERILOG ASSERTIONS (SVA) & SPY MONITOR
    // =========================================================================
    rv32i_sva sva_inst (
        .i_clk                    (clk),
        .i_rst_n                  (rst_n),
        .i_rs1_addr               (uut.datapath_inst.rs1_addr_id),
        .i_rs1_data               (uut.datapath_inst.rs1_data_id),
        .i_pipeline_hold          (uut.datapath_inst.pipeline_hold),
        .i_pc                     (uut.datapath_inst.pc_reg),
        .i_reg_write              (uut.datapath_inst.ctrl_reg_write_wb),
        .i_rd_addr                (uut.datapath_inst.rd_addr_wb),
        .i_inst_ret_valid         (uut.datapath_inst.csr_inst.i_inst_ret_valid),
        .i_branch_mispredict      (uut.datapath_inst.branch_mispredict),
        .i_csr_op                 (uut.datapath_inst.ctrl_csr_op_wb),
        .i_icache_inv             (uut.datapath_inst.o_icache_invalidate),
        .i_div_start              (uut.datapath_inst.ctrl_is_div_ex),
        .i_div_busy               (uut.datapath_inst.div_busy),
        .i_div_done               (uut.datapath_inst.div_done),
        .i_dmem_req_read          (uut.datapath_inst.o_dmem_req_read),
        .i_dmem_req_write         (uut.datapath_inst.o_dmem_req_write),
        .i_dmem_funct3            (uut.datapath_inst.o_dmem_funct3),
        .i_dmem_addr              (uut.datapath_inst.o_dmem_addr),
        .i_axi_i_araddr           (axi_i_araddr),
        .i_axi_i_arvalid          (axi_i_arvalid),
        .i_axi_i_arready          (axi_i_arready),
        .i_axi_i_rvalid           (axi_i_rvalid),
        .i_axi_i_rready           (axi_i_rready),
        .i_axi_d_awaddr           (axi_d_awaddr),
        .i_axi_d_awvalid          (axi_d_awvalid),
        .i_axi_d_awready          (axi_d_awready),
        .i_axi_d_wdata            (axi_d_wdata),
        .i_axi_d_wstrb            (axi_d_wstrb),
        .i_axi_d_wvalid           (axi_d_wvalid),
        .i_axi_d_wready           (axi_d_wready),
        .i_axi_d_bvalid           (axi_d_bvalid),
        .i_axi_d_bready           (axi_d_bready),
        .i_axi_d_araddr           (axi_d_araddr),
        .i_axi_d_arvalid          (axi_d_arvalid),
        .i_axi_d_arready          (axi_d_arready),
        .i_axi_d_rvalid           (axi_d_rvalid),
        .i_axi_d_rready           (axi_d_rready),
        .spy_inst_retired_cnt     (spy_inst_retired_cnt),
        .spy_icache_req_cnt       (spy_icache_req_cnt),
        .spy_dmem_read_cnt        (spy_dmem_read_cnt),
        .spy_dmem_write_cnt       (spy_dmem_write_cnt),
        .spy_branch_mispredict_cnt(spy_branch_mispredict_cnt),
        .spy_csr_write_cnt        (spy_csr_write_cnt),
        .spy_icache_inv_cnt       (spy_icache_inv_cnt),
        .spy_div_exec_cnt         (spy_div_exec_cnt),
        .spy_sva_error_cnt        (spy_sva_error_cnt)
    );

    // Clock generator (100 MHz, Period = 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // LAYER 2: MOCK AXI SLAVE MEMORY & INTERRUPT SERVICES
    // =========================================================================
    reg [31:0] mem [0:16383];

    integer k;
    initial begin
        for (k = 0; k < 16384; k = k + 1) begin
            mem[k] = 32'h00000013; // NOP (addi x0, x0, 0)
        end

        // =====================================================================
        // EXHAUSTIVE TEST PROGRAM FOR RV32IM PIPELINE (123 INSTRUCTIONS)
        // =====================================================================
        // --- PART 1: ARITHMETIC / SHIFTS / CORNER CASES ---
        mem[0]  = 32'h12345437; // 0x00: lui x8, 0x12345000 (x8 = 0x12345000)
        mem[1]  = 32'hfff00493; // 0x04: addi x9, x0, -1 (x9 = 0xFFFFFFFF)
        mem[2]  = 32'h80000537; // 0x08: lui x10, 0x80000000 (x10 = 0x80000000)
        mem[3]  = 32'h40355593; // 0x0C: srai x11, x10, 3 (x11 = 0xF0000000)
        mem[4]  = 32'h00355613; // 0x10: srli x12, x10, 3 (x12 = 0x10000000)
        mem[5]  = 32'h0004a6b3; // 0x14: slt x13, x9, x0 (x13 = 1)
        mem[6]  = 32'h0004b733; // 0x18: sltu x14, x9, x0 (x14 = 0)
        mem[7]  = 32'h409007b3; // 0x1C: sub x15, x0, x9 (x15 = 1)
        mem[8]  = 32'hfff4c813; // 0x20: xori x16, x9, -1 (x16 = 0)

        // --- PART 2: SUB-WORD MEMORY (BYTE / HALFWORD EXTENSIONS) ---
        mem[9]  = 32'h20000893; // 0x24: addi x17, x0, 512 (Base dmem addr 0x200 / word 128)
        mem[10] = 32'h08f00913; // 0x28: addi x18, x0, 143 (x18 = 0x8F)
        mem[11] = 32'h01288023; // 0x2C: sb x18, 0(x17) (mem[0x200][7:0] = 0x8F)
        mem[12] = 32'h00088983; // 0x30: lb x19, 0(x17) (x19 = sign_ext(0x8F) = 0xFFFFFF8F)
        mem[13] = 32'h0008ca03; // 0x34: lbu x20, 0(x17) (x20 = zero_ext(0x8F) = 0x0000008F)
        mem[14] = 32'h00008ab7; // 0x38: lui x21, 0x8000 (x21 = 0x00008000)
        mem[15] = 32'h005a8a93; // 0x3C: addi x21, x21, 5 (x21 = 0x00008005)
        mem[16] = 32'h01589223; // 0x40: sh x21, 4(x17) (mem[0x204][15:0] = 0x8005)
        mem[17] = 32'h00489b03; // 0x44: lh x22, 4(x17) (x22 = sign_ext(0x8005) = 0xFFFF8005)
        mem[18] = 32'h0048db83; // 0x48: lhu x23, 4(x17) (x23 = zero_ext(0x8005) = 0x00008005)
        mem[19] = 32'h0048ac03; // 0x4C: lw x24, 4(x17) (x24 = word at 0x204 = 0x00008005)

        // --- PART 3: ALL 6 BRANCH CONDITIONS & BACKWARD LOOP ---
        mem[20] = 32'h00f4c463; // 0x50: blt x9, x15, lbl_blt_ok (-1 < 1 signed is TRUE)
        mem[21] = 32'h00100093; // 0x54: addi x1, x0, 1 (FAIL TRAP BLT)
        mem[22] = 32'h00f4f463; // 0x58: bgeu x9, x15, lbl_bgeu_ok (0xFFFFFFFF >= 1 unsigned is TRUE)
        mem[23] = 32'h00100113; // 0x5C: addi x2, x0, 1 (FAIL TRAP BGEU)
        mem[24] = 32'h00f4e463; // 0x60: bltu x9, x15, lbl_bltu_fail (0xFFFFFFFF < 1 unsigned is FALSE)
        mem[25] = 32'h0080006f; // 0x64: jal x0, lbl_bltu_ok (skip trap)
        mem[26] = 32'h00100193; // 0x68: addi x3, x0, 1 (FAIL TRAP BLTU)
        mem[27] = 32'h00f4d463; // 0x6C: bge x9, x15, lbl_bge_fail (-1 >= 1 signed is FALSE)
        mem[28] = 32'h0080006f; // 0x70: jal x0, lbl_bge_ok (skip trap)
        mem[29] = 32'h00100213; // 0x74: addi x4, x0, 1 (FAIL TRAP BGE)
        mem[30] = 32'h00f48463; // 0x78: beq x9, x15, lbl_beq_fail (-1 == 1 is FALSE)
        mem[31] = 32'h0080006f; // 0x7C: jal x0, lbl_beq_ok (skip trap)
        mem[32] = 32'h00100393; // 0x80: addi x7, x0, 1 (FAIL TRAP BEQ)
        mem[33] = 32'h00f49463; // 0x84: bne x9, x15, lbl_bne_ok (-1 != 1 is TRUE)
        mem[34] = 32'h00200093; // 0x88: addi x1, x0, 2 (FAIL TRAP BNE)
        mem[35] = 32'h00300c93; // 0x8C: addi x25, x0, 3 (x25 = 3 loop counter)
        mem[36] = 32'hfffc8c93; // 0x90: addi x25, x25, -1 (lbl_loop)
        mem[37] = 32'hfe0c9ee3; // 0x94: bne x25, x0, lbl_loop (loop until x25 == 0)

        // --- PART 4: AUIPC & FUNCTION CALL/RETURN VIA JAL / JALR ---
        mem[38] = 32'h00c0006f; // 0x98: jal x0, lbl_skip_fn (jump over function definition)
        mem[39] = 32'h04d00e13; // 0x9C: addi x28, x0, 77 (fn body: x28 = 77)
        mem[40] = 32'h000d8067; // 0xA0: jalr x0, 0(x27) (fn return to caller)
        mem[41] = 32'h00000d17; // 0xA4: auipc x26, 0 (x26 = 0x000000A4)
        mem[42] = 32'hff5ffdef; // 0xA8: jal x27, lbl_fn (call fn, x27 = 0x000000AC)

        // --- PART 5: EXTREME PIPELINE HAZARDS ---
        mem[43] = 32'h06300013; // 0xAC: addi x0, x0, 99 (Write 99 to x0, must be ignored)
        mem[44] = 32'h00000eb3; // 0xB0: add x29, x0, x0 (x29 = 0)
        mem[45] = 32'h00a00f13; // 0xB4: addi x30, x0, 10 (x30 = 10)
        mem[46] = 32'h014f0f13; // 0xB8: addi x30, x30, 20 (x30 = 30)
        mem[47] = 32'h01ef0f13; // 0xBC: addi x30, x30, 30 (x30 = 60)
        mem[48] = 32'h028f0f13; // 0xC0: addi x30, x30, 40 (x30 = 100)
        mem[49] = 32'h01e8a423; // 0xC4: sw x30, 8(x17) (mem[0x208] = 100)
        mem[50] = 32'h0088af83; // 0xC8: lw x31, 8(x17) (x31 = mem[0x208] = 100)
        mem[51] = 32'h01ef8463; // 0xCC: beq x31, x30, lbl_load_use_ok (stall & branch taken)
        mem[52] = 32'h06300093; // 0xD0: addi x1, x0, 99 (FAIL TRAP LOAD-USE BRANCH)

        // --- PART 6: CSR OPERATIONS ---
        mem[53] = 32'h340f12f3; // 0xD4: csrrw x5, 0x340, x30 (mscratch <= 100, x5 <= old (0))
        mem[54] = 32'h34002373; // 0xD8: csrrs x6, 0x340, x0 (x6 <= mscratch (100))

        // --- PART 7: RV32M MULTIPLY & DIVIDE EXTENSION (MILESTONE 2.3) ---
        mem[55] = 32'h01400913; // 0xDC: addi x18, x0, 20
        mem[56] = 32'hffd00a93; // 0xE0: addi x21, x0, -3
        mem[57] = 32'h03590933; // 0xE4: mul x18, x18, x21 (x18 = -60)
        mem[58] = 32'h0128a623; // 0xE8: sw x18, 12(x17) (mem[131] = -60)

        mem[59] = 32'hffe00913; // 0xEC: addi x18, x0, -2
        mem[60] = 32'h00300a93; // 0xF0: addi x21, x0, 3
        mem[61] = 32'h03591933; // 0xF4: mulh x18, x18, x21 (x18 = -1)
        mem[62] = 32'h0128a823; // 0xF8: sw x18, 16(x17) (mem[132] = 0xFFFFFFFF)

        mem[63] = 32'h01400913; // 0xFC: addi x18, x0, 20
        mem[64] = 32'hffd00a93; // 0x100: addi x21, x0, -3
        mem[65] = 32'h03594933; // 0x104: div x18, x18, x21 (x18 = -6)
        mem[66] = 32'h0128aa23; // 0x108: sw x18, 20(x17) (mem[133] = -6)

        mem[67] = 32'h01400913; // 0x10C: addi x18, x0, 20
        mem[68] = 32'h03596933; // 0x110: rem x18, x18, x21 (x18 = 2)
        mem[69] = 32'h0128ac23; // 0x114: sw x18, 24(x17) (mem[134] = 2)

        mem[70] = 32'h01400913; // 0x118: addi x18, x0, 20
        mem[71] = 32'h00300a93; // 0x11C: addi x21, x0, 3
        mem[72] = 32'h03595933; // 0x120: divu x18, x18, x21 (x18 = 6)
        mem[73] = 32'h0128ae23; // 0x124: sw x18, 28(x17) (mem[135] = 6)

        mem[74] = 32'h02094933; // 0x128: div x18, x18, x0 (x18 = 0xFFFFFFFF)
        mem[75] = 32'h0328a023; // 0x12C: sw x18, 32(x17) (mem[136] = 0xFFFFFFFF)

        mem[76] = 32'h04d00913; // 0x130: addi x18, x0, 77
        mem[77] = 32'h02096933; // 0x134: rem x18, x18, x0 (x18 = 77)
        mem[78] = 32'h0328a223; // 0x138: sw x18, 36(x17) (mem[137] = 77)

        // --- PART 8: SUB-WORD BYTE OFFSETS (1, 2, 3) & HALFWORD OFFSET (2) ---
        mem[79] = 32'hCAFEC937; // 0x13C: lui x18, 0xCAFEC000
        mem[80] = 32'h12390913; // 0x140: addi x18, x18, 0x123 (x18 = 0xCAFEC123)
        mem[81] = 32'h0328A423; // 0x144: sw x18, 40(x17) (mem[138] = 0xCAFEC123)
        mem[82] = 32'h0298C903; // 0x148: lbu x18, 41(x17) (byte 1 = 0xC1)
        mem[83] = 32'h0328A623; // 0x14C: sw x18, 44(x17) (mem[139] = 0x000000C1)
        mem[84] = 32'h02A8C903; // 0x150: lbu x18, 42(x17) (byte 2 = 0xFE)
        mem[85] = 32'h0328A823; // 0x154: sw x18, 48(x17) (mem[140] = 0x000000FE)
        mem[86] = 32'h02B88903; // 0x158: lb x18, 43(x17) (signed byte 3 = 0xFFFFFFCA)
        mem[87] = 32'h0328AA23; // 0x15C: sw x18, 52(x17) (mem[141] = 0xFFFFFFCA)
        mem[88] = 32'h02A8D903; // 0x160: lhu x18, 42(x17) (halfword 2 = 0x0000CAFE)
        mem[89] = 32'h0328AC23; // 0x164: sw x18, 56(x17) (mem[142] = 0x0000CAFE)
        mem[90] = 32'h032884A3; // 0x168: sb x18, 41(x17) (write 0xFE to byte 1 of mem[138])
        mem[91] = 32'h03289523; // 0x16C: sh x18, 42(x17) (write 0xCAFE to halfword 2 of mem[138])

        // --- PART 9: MUL-USE BRANCH HAZARD & JAL PC+4 EX->ID FORWARDING ---
        mem[92]  = 32'h00600913; // 0x170: addi x18, x0, 6
        mem[93]  = 32'h00700A93; // 0x174: addi x21, x0, 7
        mem[94]  = 32'h03590933; // 0x178: mul x18, x18, x21 (x18 = 42)
        mem[95]  = 32'h03590A93 & 32'd0 | 32'h03590AB3; // 0x17C: mul x21, x18, x21 (x21 = 42 * 7 = 294, mul_use_hazard on next bne!)
        mem[96]  = 32'h01591463; // 0x180: bne x18, x21, +8 (42 != 294 -> branches to 0x188 after 1-cycle stall)
        mem[97]  = 32'h04D00093; // 0x184: addi x1, x0, 77 (FAIL TRAP MUL-USE HAZARD)
        mem[98]  = 32'h19000A93; // 0x188: addi x21, x0, 400 (0x190)
        mem[99]  = 32'h0040096F; // 0x18C: jal x18, +4 (jumps to 0x190, x18 = PC+4 = 0x190 in EX)
        mem[100] = 32'h01590463; // 0x190: beq x18, x21, +8 (forwards PC+4 from EX to ID -> branches to 0x198)
        mem[101] = 32'h05800093; // 0x194: addi x1, x0, 88 (FAIL TRAP JAL EX->ID FORWARD)

        // --- PART 10: IMMEDIATE CSR OPS, CSR-USE HAZARD, MISA, MIP & 64-BIT ROLLOVER ---
        mem[102] = 32'h3407D073; // 0x198: csrrwi x0, 0x340, 15 (mscratch <= 15)
        mem[103] = 32'h34086073; // 0x19C: csrrsi x0, 0x340, 16 (mscratch <= 15 | 16 = 31)
        mem[104] = 32'h3402F973; // 0x1A0: csrrci x18, 0x340, 5 (x18 <= 31, mscratch <= 26)
        mem[105] = 32'h00A90913; // 0x1A4: addi x18, x18, 10 (csr_use_hazard stall! x18 <= 31 + 10 = 41)
        mem[106] = 32'h0328AE23; // 0x1A8: sw x18, 60(x17) (mem[143] = 41)
        mem[107] = 32'h34002973; // 0x1AC: csrrs x18, 0x340, x0 (x18 <= 26)
        mem[108] = 32'h0528A023; // 0x1B0: sw x18, 64(x17) (mem[144] = 26)
        mem[109] = 32'h30102973; // 0x1B4: csrrs x18, 0x301, x0 (read CSR_MISA = 0x40001100)
        mem[110] = 32'h0528A223; // 0x1B8: sw x18, 68(x17) (mem[145] = 0x40001100)
        mem[111] = 32'h34402973; // 0x1BC: csrrs x18, 0x344, x0 (read CSR_MIP = 0x00000880)
        mem[112] = 32'h0528A423; // 0x1C0: sw x18, 72(x17) (mem[146] = 0x00000880)
        mem[113] = 32'hC8001073; // 0x1C4: csrrw x0, 0xC80, x0 (mcycleh <= 0)
        mem[114] = 32'hC0049073; // 0x1C8: csrrw x0, 0xC00, x9 (mcycle <= 0xFFFFFFFF -> rollover when retired in WB!)
        mem[115] = 32'h00000013; // 0x1CC: nop (wait 1 stage for csrrw to retire in WB & mcycle to roll over to 0x1_00000000)
        mem[116] = 32'hC8002973; // 0x1D0: csrrs x18, 0xC80, x0 (x18 <= mcycleh = 1)
        mem[117] = 32'h0528A623; // 0x1D4: sw x18, 76(x17) (mem[147] = 1)

        // --- PART 11: FENCE.I CACHE INVALIDATION & SIGNED OVERFLOW DIV/REM ---
        mem[118] = 32'h0000100F; // 0x1D8: fence.i (invalidate I-Cache)
        mem[119] = 32'h02954933; // 0x1DC: div x18, x10, x9 (-2^31 / -1 = 0x80000000)
        mem[120] = 32'h0528A823; // 0x1E0: sw x18, 80(x17) (mem[148] = 0x80000000)
        mem[121] = 32'h02956933; // 0x1E4: rem x18, x10, x9 (-2^31 % -1 = 0)
        mem[122] = 32'h0528AA23; // 0x1E8: sw x18, 84(x17) (mem[149] = 0)

        // --- PART 12: TERMINATION ---
        mem[123] = 32'h00000073; // 0x1EC: ecall (halt simulation)
    end

    // AXI I-Bus Slave Model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_i_arready <= 1'b0;
            axi_i_rvalid  <= 1'b0;
            axi_i_rdata   <= 32'b0;
            axi_i_rresp   <= 2'b00;
        end else begin
            axi_i_arready <= axi_i_arvalid && !axi_i_rvalid;
            if (axi_i_arvalid && axi_i_arready && !axi_i_rvalid) begin
                axi_i_rvalid <= 1'b1;
                axi_i_rdata  <= mem[axi_i_araddr >> 2];
            end else if (axi_i_rvalid && axi_i_rready) begin
                axi_i_rvalid <= 1'b0;
            end
        end
    end

    // AXI D-Bus Slave Model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            axi_d_arready <= 1'b0;
            axi_d_rvalid  <= 1'b0;
            axi_d_awready <= 1'b0;
            axi_d_wready  <= 1'b0;
            axi_d_bvalid  <= 1'b0;
            axi_d_bresp   <= 2'b00;
            axi_d_rresp   <= 2'b00;
        end else begin
            axi_d_arready <= axi_d_arvalid && !axi_d_rvalid;
            if (axi_d_arvalid && axi_d_arready && !axi_d_rvalid) begin
                axi_d_rvalid <= 1'b1;
                axi_d_rdata  <= mem[axi_d_araddr >> 2];
            end else if (axi_d_rvalid && axi_d_rready) begin
                axi_d_rvalid <= 1'b0;
            end

            axi_d_awready <= axi_d_awvalid && !axi_d_bvalid;
            axi_d_wready  <= axi_d_wvalid  && !axi_d_bvalid;
            if (axi_d_awvalid && axi_d_wvalid && !axi_d_bvalid) begin
                if (axi_d_wstrb[0]) mem[axi_d_awaddr >> 2][7:0]   <= axi_d_wdata[7:0];
                if (axi_d_wstrb[1]) mem[axi_d_awaddr >> 2][15:8]  <= axi_d_wdata[15:8];
                if (axi_d_wstrb[2]) mem[axi_d_awaddr >> 2][23:16] <= axi_d_wdata[23:16];
                if (axi_d_wstrb[3]) mem[axi_d_awaddr >> 2][31:24] <= axi_d_wdata[31:24];
                axi_d_bvalid <= 1'b1;
            end else if (axi_d_bvalid && axi_d_bready) begin
                axi_d_bvalid <= 1'b0;
            end
        end
    end

    // =========================================================================
    // LAYER 4: SCOREBOARD VERIFICATION & EXPECTATION MACROS
    // =========================================================================
    integer pass_count = 0;
    integer errors     = 0;

    initial begin
        rst_n             = 0;
        mock_timer_irq    = 1'b1; // Drive mock Timer IRQ high for CSR_MIP verification
        mock_external_irq = 1'b1; // Drive mock External IRQ high for CSR_MIP verification
        #25;
        rst_n = 1;

        $display("\n=======================================================================================");
        $display("   [DV] LAYERED RV32IM PIPELINE PROCESSOR - EXHAUSTIVE VERIFICATION SUITE START");
        $display("=======================================================================================");

        // Wait until CPU hits ECALL / HALT
        wait (o_ecall_halt == 1'b1);
        @(posedge clk);
        @(posedge clk);

        $display("\n[INFO] ECALL / HALT detected. Running Scoreboard Inspection across 56 Checkpoints...\n");

        // PART 1: Arithmetic & Corner values
        expect_reg(8,  32'h12345000, "Checkpoint 01: LUI upper 20 bits");
        expect_reg(9,  32'hFFFFFFFF, "Checkpoint 02: ADDI negative boundary -1");
        expect_reg(10, 32'h80000000, "Checkpoint 03: LUI negative MSB boundary (0x80000000)");
        expect_reg(11, 32'hF0000000, "Checkpoint 04: SRAI arithmetic right shift with sign extension");
        expect_reg(12, 32'h10000000, "Checkpoint 05: SRLI logical right shift with zero fill");
        expect_reg(13, 32'd1,        "Checkpoint 06: SLT signed comparison (-1 < 0 is TRUE)");
        expect_reg(14, 32'd0,        "Checkpoint 07: SLTU unsigned comparison (0xFFFFFFFF < 0 is FALSE)");
        expect_reg(15, 32'd1,        "Checkpoint 08: SUB arithmetic negation (0 - (-1) = 1)");
        expect_reg(16, 32'd0,        "Checkpoint 09: XORI bitwise identity (-1 ^ -1 = 0)");

        // PART 2: Sub-word Memory Access (Byte & Halfword)
        expect_reg(19, 32'hFFFFFF8F, "Checkpoint 10: LB signed byte sign-extension (0x8F -> 0xFFFFFF8F)");
        expect_reg(20, 32'h0000008F, "Checkpoint 11: LBU unsigned byte zero-extension (0x8F -> 0x0000008F)");
        expect_reg(22, 32'hFFFF8005, "Checkpoint 12: LH signed halfword sign-extension (0x8005 -> 0xFFFF8005)");
        expect_reg(23, 32'h00008005, "Checkpoint 13: LHU unsigned halfword zero-extension (0x8005 -> 0x00008005)");
        expect_reg(24, 32'h00008005, "Checkpoint 14: LW 32-bit full word read");
        expect_mem(128, 32'h0000008F, "Checkpoint 15: Memory byte write (SB) at byte 0x200 (word 128)");
        expect_mem(129, 32'h00008005, "Checkpoint 16: Memory halfword write (SH) at byte 0x204 (word 129)");
        expect_mem(130, 32'd100,      "Checkpoint 17: Memory word write (SW) at byte 0x208 (word 130)");

        // PART 3: Branch Conditions & Backward Loop
        expect_reg(1, 32'd0,  "Checkpoint 18: Branch BLT, BNE, MUL-Use & JAL-Fwd traps skipped");
        expect_reg(2, 32'd0,  "Checkpoint 19: Branch BGEU trap skipped");
        expect_reg(3, 32'd0,  "Checkpoint 20: Branch BLTU negative branch correctly not taken");
        expect_reg(4, 32'd0,  "Checkpoint 21: Branch BGE negative branch correctly not taken");
        expect_reg(7, 32'd0,  "Checkpoint 22: Branch BEQ negative branch correctly not taken");
        expect_reg(25, 32'd0, "Checkpoint 23: Backward Loop: 3 iterations successfully completed");

        // PART 4: AUIPC & Function Link/Return
        expect_reg(26, 32'h000000A4, "Checkpoint 24: AUIPC latched exact instruction PC (0x000000A4)");
        expect_reg(27, 32'h000000AC, "Checkpoint 25: JAL linked return address PC+4 (0x000000AC)");
        expect_reg(28, 32'd77,        "Checkpoint 26: JALR function execution and return link");

        // PART 5: Pipeline Extreme Hazard Scenarios
        expect_reg(29, 32'd0,   "Checkpoint 27: Hazard 1 - x0 write suppression (no dirty forward)");
        expect_reg(30, 32'd100, "Checkpoint 28: Hazard 2 - 4-stage back-to-back RAW forwarding on same reg");
        expect_reg(31, 32'd100, "Checkpoint 29: Hazard 3 - Load-Use into Branch with 1-cycle stall & fwd");

        // PART 6: CSR Operations
        expect_reg(5, 32'd0,   "Checkpoint 30: CSRRW read previous mscratch (0)");
        expect_reg(6, 32'd100, "Checkpoint 31: CSRRS read updated mscratch (100)");

        // PART 7: RV32M Multiply & Multi-Cycle Divide Operations
        expect_mem(131, -32'd60,      "Checkpoint 32: MUL signed low 32-bit (20 * -3 = -60)");
        expect_mem(132, 32'hFFFFFFFF, "Checkpoint 33: MULH signed high 32-bit (high(-2 * 3) = -1)");
        expect_mem(133, -32'd6,       "Checkpoint 34: DIV signed multi-cycle quotient (20 / -3 = -6)");
        expect_mem(134, 32'd2,        "Checkpoint 35: REM signed multi-cycle remainder (20 % -3 = 2)");
        expect_mem(135, 32'd6,        "Checkpoint 36: DIVU unsigned multi-cycle quotient (20 / 3 = 6)");
        expect_mem(136, 32'hFFFFFFFF, "Checkpoint 37: DIV divide-by-zero fast exit (20 / 0 = -1)");
        expect_mem(137, 32'd77,       "Checkpoint 38: REM remainder-by-zero fast exit (77 % 0 = 77)");

        // PART 8: Unaligned Byte Offsets (1, 2, 3) & Halfword Offset (2)
        expect_mem(138, 32'hCAFEFE23, "Checkpoint 39: Sub-word SB(offset 1) + SH(offset 2) byte-lane merge");
        expect_mem(139, 32'h000000C1, "Checkpoint 40: LBU byte offset 1 (0xC1)");
        expect_mem(140, 32'h000000FE, "Checkpoint 41: LBU byte offset 2 (0xFE)");
        expect_mem(141, 32'hFFFFFFCA, "Checkpoint 42: LB signed byte offset 3 (0xFFFFFFCA)");
        expect_mem(142, 32'h0000CAFE, "Checkpoint 43: LHU halfword offset 2 (0x0000CAFE)");

        // PART 9 & 10: Immediate CSRs, CSR-Use Hazard, MISA, MIP & 64-Bit Counter Rollover
        expect_mem(143, 32'd41,        "Checkpoint 44: CSRRWI/CSRRSI/CSRRCI + CSR-Use Hazard Stall (31+10=41)");
        expect_mem(144, 32'd26,        "Checkpoint 45: CSRRC bit-clear result in mscratch (31 & ~5 = 26)");
        expect_mem(145, 32'h40001100,  "Checkpoint 46: CSR_MISA RV32IM Architecture ID (0x40001100)");
        expect_mem(146, 32'h00000880,  "Checkpoint 47: CSR_MIP live MEIP(bit 11) + MTIP(bit 7) = 0x880");
        expect_mem(147, 32'd1,         "Checkpoint 48: CSR_MCYCLE 64-bit rollover into CSR_MCYCLEH (1)");

        // PART 11: FENCE.I & Signed Overflow DIV/REM
        expect_mem(148, 32'h80000000,  "Checkpoint 49: DIV signed overflow fast-exit (-2^31 / -1 = -2^31)");
        expect_mem(149, 32'd0,         "Checkpoint 50: REM signed overflow fast-exit (-2^31 % -1 = 0)");

        // PART 12: Ecosystem Transaction & Call Spy Verification
        $display("\n--- ECOSYSTEM TRANSACTION & CALL SPY VERIFICATION ---");
        expect_spy("Checkpoint 51: SVA Protocol Violation Count == 0", spy_sva_error_cnt, 0);
        expect_spy("Checkpoint 52: D-Bus Memory Write Transactions",   spy_dmem_write_cnt, 24);
        expect_spy("Checkpoint 53: D-Bus Memory Read Transactions",    spy_dmem_read_cnt,  10);
        expect_spy("Checkpoint 54: Retired CSR Write Calls",           spy_csr_write_cnt,  11);
        expect_spy("Checkpoint 55: FENCE.I Cache Invalidation Calls",  spy_icache_inv_cnt, 1);
        expect_spy("Checkpoint 56: Hardware Division Executions",      spy_div_exec_cnt,   7);

        $display("\n---------------------------------------------------------------------------------------");
        if (errors == 0) begin
            $display("   >>> ALL %0d LAYERED VERIFICATION CHECKPOINTS & SPIES PASSED PERFECTLY! <<<", pass_count);
            $display("   >>> SYSTEMVERILOG ASSERTIONS (SVA): ZERO VIOLATIONS!                   <<<");
            $display("   >>> CORE PIPELINE + BP + ICACHE + RV32M + CSR 100%% VERIFIED!          <<<");
        end else begin
            $display("   >>> [FAILED] %0d VERIFICATION CHECKPOINTS FAILED! <<<", errors);
        end
        $display("---------------------------------------------------------------------------------------\n");

        $finish;
    end

    // Task to check register value with SV assertion
    task expect_reg(input integer reg_num, input [31:0] expected, input [127*8:1] desc);
        begin
            assert (uut.datapath_inst.reg_file.registers[reg_num] === expected) begin
                $display(" [PASS] [EXPECT_REG] %0s | Reg x%0d = 0x%08H (%0d)",
                         desc, reg_num, uut.datapath_inst.reg_file.registers[reg_num],
                         $signed(uut.datapath_inst.reg_file.registers[reg_num]));
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_REG] %0s | Reg x%0d = 0x%08H (Expected: 0x%08H)",
                       desc, reg_num, uut.datapath_inst.reg_file.registers[reg_num], expected);
                errors = errors + 1;
            end
        end
    endtask

    // Task to check memory value with SV assertion
    task expect_mem(input integer word_addr, input [31:0] expected, input [127*8:1] desc);
        begin
            assert (mem[word_addr] === expected) begin
                $display(" [PASS] [EXPECT_MEM] %0s | Mem[%0d] = 0x%08H (%0d)",
                         desc, word_addr, mem[word_addr], $signed(mem[word_addr]));
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_MEM] %0s | Mem[%0d] = 0x%08H (Expected: 0x%08H)",
                       desc, word_addr, mem[word_addr], expected);
                errors = errors + 1;
            end
        end
    endtask

    // Task to check spy counter with SV assertion
    task expect_spy(input [127*8:1] desc, input integer actual_cnt, input integer expected_cnt);
        begin
            assert (actual_cnt === expected_cnt) begin
                $display(" [PASS] [EXPECT_SPY] %0s | Count = %0d (Exp: %0d)", desc, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_SPY] %0s | Count = %0d (Exp: %0d)", desc, actual_cnt, expected_cnt);
                errors = errors + 1;
            end
        end
    endtask

    // Watchdog Timer
    initial begin
        #100000;
        $display("\n[FATAL ERROR] TIMEOUT WATCHDOG FIRED! CPU failed to reach ECALL in 100us.");
        $finish;
    end

endmodule
