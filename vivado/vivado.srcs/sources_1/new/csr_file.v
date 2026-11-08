`timescale 1ns / 1ps

module csr_file #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // Giao tiep voi CPU Pipeline WB Stage
    input  wire [11:0]           i_csr_addr,        // Dia chi CSR (12-bit tu instr[31:20])
    input  wire [DATA_WIDTH-1:0] i_csr_wdata,       // Du lieu ghi tu RS1 hoac zimm[4:0]
    input  wire [1:0]            i_csr_op,          // 01: CSRRW(I), 10: CSRRS(I), 11: CSRRC(I)
    output reg  [DATA_WIDTH-1:0] o_csr_rdata,       // Du lieu doc ve

    input  wire                  i_inst_ret_valid,  // 1: Bao 1 lenh vua hoan thanh rut lui (Retire)
    input  wire                  i_timer_irq,       // Machine Timer Interrupt Pending (MTIP - bit 7)
    input  wire                  i_external_irq,    // Machine External Interrupt Pending (MEIP - bit 11)

    // Giao tiep Trap & Exception & Interrupt Controller
    input  wire                  i_trap_taken,      // 1: Pipeline chap nhan Trap (Ngat / Exception)
    input  wire [DATA_WIDTH-1:0] i_trap_pc,         // Dia chi PC can luu vao mepc
    input  wire [DATA_WIDTH-1:0] i_trap_cause,      // Ma nguyen nhan can luu vao mcause
    input  wire                  i_mret,            // 1: Thuc hien lenh MRET (quay ve tu Trap)

    output wire                  o_trap_irq_req,    // 1: Yeu cau ngat dang cho duoc phep kich hoat
    output wire [DATA_WIDTH-1:0] o_trap_target_pc,  // Vector ngat (gia tri mtvec)
    output wire [DATA_WIDTH-1:0] o_mepc_val,        // Dia chi quay ve (gia tri mepc)
    output wire [DATA_WIDTH-1:0] o_trap_irq_cause   // Ma cause ngat tuong ung
);

    // Bang dia chi CSR tieu chuan RISC-V Machine Mode
    localparam CSR_MSTATUS   = 12'h300;
    localparam CSR_MISA      = 12'h301;
    localparam CSR_MIE       = 12'h304;
    localparam CSR_MTVEC     = 12'h305;
    localparam CSR_MSCRATCH  = 12'h340;
    localparam CSR_MEPC      = 12'h341;
    localparam CSR_MCAUSE    = 12'h342;
    localparam CSR_MTVAL     = 12'h343;
    localparam CSR_MIP       = 12'h344;
    localparam CSR_MCYCLE    = 12'hC00;
    localparam CSR_MINSTRET  = 12'hC02;
    localparam CSR_MCYCLEH   = 12'hC80;
    localparam CSR_MINSTRETH = 12'hC82;

    // Thanh ghi noi bo
    reg [63:0]           mcycle_reg;
    reg [63:0]           minstret_reg;
    reg [DATA_WIDTH-1:0] mstatus_reg;
    reg [DATA_WIDTH-1:0] mie_reg;
    reg [DATA_WIDTH-1:0] mtvec_reg;
    reg [DATA_WIDTH-1:0] mepc_reg;
    reg [DATA_WIDTH-1:0] mcause_reg;
    reg [DATA_WIDTH-1:0] mtval_reg;
    reg [DATA_WIDTH-1:0] mscratch_reg;

    // Thanh ghi trang thai ngat dang cho MIP (Bit 11: MEIP, Bit 7: MTIP)
    wire [DATA_WIDTH-1:0] mip_val = {20'd0, i_external_irq, 3'd0, i_timer_irq, 7'd0};

    // -------------------------------------------------------------------------
    // LOGIC TONG HOP DIEU KIEN TRAP & INTERRUPT
    // -------------------------------------------------------------------------
    wire mstatus_mie          = mstatus_reg[3];
    wire mie_mtie             = mie_reg[7];
    wire mie_meie             = mie_reg[11];
    wire timer_irq_pending    = mstatus_mie && mie_mtie && i_timer_irq;
    wire external_irq_pending = mstatus_mie && mie_meie && i_external_irq;

    assign o_trap_irq_req   = timer_irq_pending || external_irq_pending;
    assign o_trap_target_pc = mtvec_reg;
    assign o_mepc_val       = mepc_reg;
    assign o_trap_irq_cause = timer_irq_pending ? 32'h8000_0007 : 32'h8000_000B;

    // -------------------------------------------------------------------------
    // 1. PERFORMANCE COUNTERS (mcycle & minstret) - Ho tro WARL Read/Write
    // -------------------------------------------------------------------------
    wire [DATA_WIDTH-1:0] csr_new_val;
    assign csr_new_val = (i_csr_op == 2'b01) ? i_csr_wdata :                  // CSRRW: Ghi truc tiep
                         (i_csr_op == 2'b10) ? (o_csr_rdata | i_csr_wdata) :  // CSRRS: Bit set
                         (i_csr_op == 2'b11) ? (o_csr_rdata & ~i_csr_wdata) : // CSRRC: Bit clear
                         o_csr_rdata;

    wire csr_write_en = (i_csr_op != 2'b00) && i_inst_ret_valid;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            mcycle_reg   <= 64'd0;
            minstret_reg <= 64'd0;
        end else begin
            // Cap nhat mcycle (uu tien ghi tu phan mem Machine-mode de ho tro kiem chung rollover)
            if (csr_write_en && (i_csr_addr == CSR_MCYCLE)) begin
                mcycle_reg[31:0] <= csr_new_val;
            end else if (csr_write_en && (i_csr_addr == CSR_MCYCLEH)) begin
                mcycle_reg[63:32] <= csr_new_val;
                mcycle_reg[31:0]  <= mcycle_reg[31:0] + 1'b1;
            end else begin
                mcycle_reg <= mcycle_reg + 1'b1; // Dem chu ky xung nhip
            end

            // Cap nhat minstret
            if (csr_write_en && (i_csr_addr == CSR_MINSTRET)) begin
                minstret_reg[31:0] <= csr_new_val;
            end else if (csr_write_en && (i_csr_addr == CSR_MINSTRETH)) begin
                minstret_reg[63:32] <= csr_new_val;
            end else if (i_inst_ret_valid) begin
                minstret_reg <= minstret_reg + 1'b1; // Dem so lenh hoan thanh (Retire)
            end
        end
    end

    // -------------------------------------------------------------------------
    // 2. DOC BAT DONG BO THANH GHI CSR
    // -------------------------------------------------------------------------
    always @(*) begin
        case (i_csr_addr)
            CSR_MCYCLE:    o_csr_rdata = mcycle_reg[31:0];
            CSR_MCYCLEH:   o_csr_rdata = mcycle_reg[63:32];
            CSR_MINSTRET:  o_csr_rdata = minstret_reg[31:0];
            CSR_MINSTRETH: o_csr_rdata = minstret_reg[63:32];
            CSR_MSTATUS:   o_csr_rdata = mstatus_reg;
            CSR_MISA:      o_csr_rdata = 32'h40001100; // RV32IM Architecture identifier (MXL=1, I=bit 8, M=bit 12)
            CSR_MIE:       o_csr_rdata = mie_reg;
            CSR_MTVEC:     o_csr_rdata = mtvec_reg;
            CSR_MEPC:      o_csr_rdata = mepc_reg;
            CSR_MCAUSE:    o_csr_rdata = mcause_reg;
            CSR_MTVAL:     o_csr_rdata = mtval_reg;
            CSR_MIP:       o_csr_rdata = mip_val;
            CSR_MSCRATCH:  o_csr_rdata = mscratch_reg;
            default:       o_csr_rdata = 32'b0;
        endcase
    end

    // -------------------------------------------------------------------------
    // 3. GHI DONG BO THANH GHI CSR (CSRRW, CSRRS, CSRRC, TRAP ENTRY, MRET)
    // -------------------------------------------------------------------------
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            mstatus_reg  <= 32'b0;
            mie_reg      <= 32'b0;
            mtvec_reg    <= 32'b0;
            mepc_reg     <= 32'b0;
            mcause_reg   <= 32'b0;
            mtval_reg    <= 32'b0;
            mscratch_reg <= 32'b0;
        end else if (i_trap_taken) begin
            mepc_reg       <= i_trap_pc;
            mcause_reg     <= i_trap_cause;
            mstatus_reg[7] <= mstatus_reg[3]; // MPIE <= MIE
            mstatus_reg[3] <= 1'b0;           // MIE <= 0
        end else if (i_mret) begin
            mstatus_reg[3] <= mstatus_reg[7]; // MIE <= MPIE
            mstatus_reg[7] <= 1'b1;           // MPIE <= 1
        end else if (csr_write_en) begin
            case (i_csr_addr)
                CSR_MSTATUS:  mstatus_reg  <= csr_new_val;
                CSR_MIE:      mie_reg      <= csr_new_val;
                CSR_MTVEC:    mtvec_reg    <= csr_new_val;
                CSR_MEPC:     mepc_reg     <= csr_new_val;
                CSR_MCAUSE:   mcause_reg   <= csr_new_val;
                CSR_MTVAL:    mtval_reg    <= csr_new_val;
                CSR_MSCRATCH: mscratch_reg <= csr_new_val;
                default: ;
            endcase
        end
    end

endmodule
