`timescale 1ns / 1ps
`include "defines.vh"

module datapath #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // Giao tiep Instruction Bus (IF Stage)
    output wire [ADDR_WIDTH-1:0] o_imem_addr,
    output wire                  o_imem_req,
    output wire                  o_imem_flush,
    output wire                  o_icache_invalidate,
    input  wire [DATA_WIDTH-1:0] i_imem_rdata,
    input  wire                  i_imem_valid,
    input  wire                  i_axi_i_stall,

    // Giao tiep Data Bus (MEM Stage)
    output wire [ADDR_WIDTH-1:0] o_dmem_addr,
    output wire [DATA_WIDTH-1:0] o_dmem_wdata,
    output wire [2:0]            o_dmem_funct3,
    output wire                  o_dmem_req_read,
    output wire                  o_dmem_req_write,
    input  wire [DATA_WIDTH-1:0] i_dmem_rdata,
    input  wire                  i_axi_d_stall,

    // Tin hieu Ngat ngoai vi (Machine Interrupt Pending)
    input  wire                  i_timer_irq,
    input  wire                  i_external_irq,

    // Status / Debug
    output wire                  o_ecall_halt
);

    // =========================================================================
    // KHAI BAO TIN HIEU GIUA CAC CONG DOAN (PIPELINE WIRES)
    // =========================================================================
    // Hazard Unit Controls
    wire pc_write, if_id_write, if_id_flush, id_ex_flush, pipeline_hold;
    wire id_ex_hold, ex_mem_flush;

    // Branch Predictor Wires
    wire                  bp_pred_taken;
    wire [ADDR_WIDTH-1:0] bp_pred_target;
    wire                  bp_update_en;
    wire [ADDR_WIDTH-1:0] bp_update_pc;
    wire                  bp_update_taken;
    wire [ADDR_WIDTH-1:0] bp_update_target;

    // IF Stage
    reg  [ADDR_WIDTH-1:0] pc_reg;
    wire [ADDR_WIDTH-1:0] pc_next, pc_plus_4;
    wire                  id_redirect;

    // ID Stage
    wire [ADDR_WIDTH-1:0] pc_id;
    wire [DATA_WIDTH-1:0] instr_id;
    wire                  pred_taken_id;
    wire [ADDR_WIDTH-1:0] pred_target_id;
    wire [4:0]            rs1_addr_id = instr_id[19:15];
    wire [4:0]            rs2_addr_id = instr_id[24:20];
    wire [4:0]            rd_addr_id  = instr_id[11:7];
    wire [2:0]            funct3_id   = instr_id[14:12];
    wire [11:0]           csr_addr_id = instr_id[31:20];

    wire ctrl_reg_write, ctrl_alu_src_a, ctrl_alu_src_b;
    wire [1:0] ctrl_wb_src;
    wire [2:0] ctrl_imm_src;
    wire [3:0] ctrl_alu_op;
    wire ctrl_branch, ctrl_jump, ctrl_jump_reg;
    wire ctrl_mem_req_read, ctrl_mem_req_write;
    wire [1:0] ctrl_csr_op;
    wire ctrl_ecall_halt;
    wire ctrl_mret;
    wire ctrl_uses_rs1, ctrl_uses_rs2;
    wire ctrl_is_mul, ctrl_is_div;
    wire ctrl_icache_inv;

    // Trap & Interrupt Signals
    wire                  trap_irq_req;
    wire [ADDR_WIDTH-1:0] trap_target_pc;
    wire [DATA_WIDTH-1:0] mepc_val;
    wire [DATA_WIDTH-1:0] trap_irq_cause;
    wire                  hazard_stall;
    wire                  trap_taken = trap_irq_req && !hazard_stall && !pipeline_hold;
    wire [ADDR_WIDTH-1:0] trap_save_pc = (pc_id != 32'd0) ? pc_id : pc_reg;

    wire [DATA_WIDTH-1:0] rs1_data_id, rs2_data_id, imm_ext_id;
    wire [DATA_WIDTH-1:0] branch_src_a, branch_src_b;
    wire br_eq, br_lt, br_ltu;
    reg  branch_taken;
    wire [ADDR_WIDTH-1:0] branch_target, jump_target, jalr_target;
    wire branch_mispredict;
    wire [ADDR_WIDTH-1:0] branch_correct_pc;

    // EX Stage
    wire [ADDR_WIDTH-1:0] pc_ex;
    wire [DATA_WIDTH-1:0] rs1_data_ex, rs2_data_ex, imm_ext_ex;
    wire [4:0]            rs1_addr_ex, rs2_addr_ex, rd_addr_ex;
    wire [2:0]            funct3_ex;
    wire [11:0]           csr_addr_ex;
    wire ctrl_reg_write_ex, ctrl_alu_src_a_ex, ctrl_alu_src_b_ex;
    wire [1:0] ctrl_wb_src_ex;
    wire [3:0] ctrl_alu_op_ex;
    wire ctrl_mem_req_read_ex, ctrl_mem_req_write_ex;
    wire [1:0] ctrl_csr_op_ex;
    wire ctrl_ecall_halt_ex;
    wire ctrl_is_mul_ex, ctrl_is_div_ex;

    wire [1:0] forward_a, forward_b;
    wire [DATA_WIDTH-1:0] alu_in_a_raw, alu_in_b_raw;
    wire [DATA_WIDTH-1:0] alu_in_a, alu_in_b;
    wire [DATA_WIDTH-1:0] alu_result_ex;
    wire [DATA_WIDTH-1:0] mul_result_ex;
    wire [DATA_WIDTH-1:0] div_result_ex;
    wire [DATA_WIDTH-1:0] ex_final_result;
    wire                  div_busy, div_done;

    // MEM Stage
    wire [ADDR_WIDTH-1:0] pc_mem;
    wire [DATA_WIDTH-1:0] alu_result_mem, rs2_data_mem;
    wire [4:0]            rd_addr_mem;
    wire [2:0]            funct3_mem;
    wire [11:0]           csr_addr_mem;
    wire [DATA_WIDTH-1:0] csr_wdata_mem;
    wire ctrl_reg_write_mem;
    wire [1:0] ctrl_wb_src_mem;
    wire ctrl_mem_req_read_mem, ctrl_mem_req_write_mem;
    wire [1:0] ctrl_csr_op_mem;
    wire ctrl_ecall_halt_mem;

    wire [DATA_WIDTH-1:0] fwd_data_mem;

    // WB Stage
    wire [ADDR_WIDTH-1:0] pc_wb;
    wire [DATA_WIDTH-1:0] alu_result_wb, mem_rdata_wb, wb_final_data;
    wire [4:0]            rd_addr_wb;
    wire [11:0]           csr_addr_wb;
    wire [DATA_WIDTH-1:0] csr_wdata_wb;
    wire ctrl_reg_write_wb;
    wire [1:0] ctrl_wb_src_wb;
    wire [1:0] ctrl_csr_op_wb;
    wire ctrl_ecall_halt_wb;
    wire [DATA_WIDTH-1:0] csr_rdata_wb;

    // =========================================================================
    // 1. IF STAGE (INSTRUCTION FETCH & DYNAMIC BRANCH PREDICTION)
    // =========================================================================
    branch_predictor #(
        .ENTRY_COUNT (64),
        .ADDR_WIDTH  (32)
    ) bp_inst (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_pc            (pc_reg),
        .o_pred_taken    (bp_pred_taken),
        .o_pred_target   (bp_pred_target),
        .i_update_en     (bp_update_en),
        .i_update_pc     (bp_update_pc),
        .i_update_taken  (bp_update_taken),
        .i_update_target (bp_update_target)
    );

    assign pc_plus_4   = pc_reg + 32'd4;
    assign o_imem_addr = pc_reg;
    assign o_imem_req  = 1'b1;

    // Pipeline redirection khi co Trap / MRET / Jump / Misprediction tai ID stage
    assign id_redirect  = trap_taken || ctrl_mret || branch_mispredict || ctrl_jump_reg || (ctrl_jump && !pred_taken_id);
    assign o_imem_flush = id_redirect;

    // Chon PC ke tiep:
    // Uu tien 1: Trap Vector (mtvec) khi co Ngat / Exception
    // Uu tien 2: Return Address (mepc) khi co lenh MRET
    // Uu tien 3: Pipeline Redirection tu ID Stage (Mispredict / JALR / Cold-start JAL)
    // Uu tien 4: Dynamic Branch Prediction tu BTB (Predict Taken)
    // Uu tien 5: PC + 4 (Normal sequential execution)
    assign pc_next = (trap_taken)                  ? trap_target_pc :
                     (ctrl_mret)                   ? mepc_val :
                     (branch_mispredict)           ? branch_correct_pc :
                     (ctrl_jump_reg)               ? jalr_target :
                     (ctrl_jump && !pred_taken_id) ? jump_target :
                     (bp_pred_taken)               ? bp_pred_target :
                                                     pc_plus_4;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            pc_reg <= `ADDR_WIDTH'b0;
        end else if (!pipeline_hold && pc_write) begin
            if (id_redirect) begin
                pc_reg <= pc_next;
            end else if (i_imem_valid) begin
                pc_reg <= pc_next;
            end
        end
    end

    if_id_reg IF_ID (
        .i_clk         (i_clk),
        .i_rst_n       (i_rst_n),
        .i_hold        (pipeline_hold || !if_id_write),
        .i_flush       (if_id_flush),
        .i_valid       (i_imem_valid),
        .i_pc          (pc_reg),
        .i_instr       (i_imem_rdata),
        .i_pred_taken  (bp_pred_taken),
        .i_pred_target (bp_pred_target),
        .o_pc          (pc_id),
        .o_instr       (instr_id),
        .o_pred_taken  (pred_taken_id),
        .o_pred_target (pred_target_id)
    );

    // =========================================================================
    // 2. ID STAGE (DECODE, BRANCH RESOLUTION & PREDICTOR TRAINING)
    // =========================================================================
    control_unit ctrl_unit (
        .i_opcode        (instr_id[6:0]),
        .i_funct3        (instr_id[14:12]),
        .i_funct7        (instr_id[31:25]),
        .i_funct12       (instr_id[31:20]),
        .o_reg_write     (ctrl_reg_write),
        .o_wb_src        (ctrl_wb_src),
        .o_alu_src_a     (ctrl_alu_src_a),
        .o_alu_src_b     (ctrl_alu_src_b),
        .o_imm_src       (ctrl_imm_src),
        .o_alu_op        (ctrl_alu_op),
        .o_branch        (ctrl_branch),
        .o_jump          (ctrl_jump),
        .o_jump_reg      (ctrl_jump_reg),
        .o_mem_req_read  (ctrl_mem_req_read),
        .o_mem_req_write (ctrl_mem_req_write),
        .o_csr_op        (ctrl_csr_op),
        .o_ecall_halt    (ctrl_ecall_halt),
        .o_mret          (ctrl_mret),
        .o_uses_rs1      (ctrl_uses_rs1),
        .o_uses_rs2      (ctrl_uses_rs2),
        .o_is_mul        (ctrl_is_mul),
        .o_is_div        (ctrl_is_div),
        .o_icache_inv    (ctrl_icache_inv)
    );

    assign o_icache_invalidate = ctrl_icache_inv && !pipeline_hold;

    register_file reg_file (
        .i_clk       (i_clk),
        .i_rst_n     (i_rst_n),
        .i_rs1_addr  (rs1_addr_id),
        .o_rs1_data  (rs1_data_id),
        .i_rs2_addr  (rs2_addr_id),
        .o_rs2_data  (rs2_data_id),
        .i_reg_write (ctrl_reg_write_wb),
        .i_rd_addr   (rd_addr_wb),
        .i_rd_data   (wb_final_data)
    );

    imm_gen imm_generator (
        .i_instr   (instr_id),
        .i_imm_src (ctrl_imm_src),
        .o_imm_ext (imm_ext_id)
    );

    // Du lieu forwarded chuan xac tu EX Stage va MEM Stage
    wire [DATA_WIDTH-1:0] fwd_data_ex = (ctrl_wb_src_ex == `WB_SRC_PC_PLUS4) ? (pc_ex + 32'd4) : alu_result_ex;

    assign fwd_data_mem = (ctrl_wb_src_mem == `WB_SRC_MEM)     ? i_dmem_rdata :
                          (ctrl_wb_src_mem == `WB_SRC_PC_PLUS4) ? (pc_mem + 32'd4) :
                                                                  alu_result_mem;

    // Early Branch Forwarding MUXes tu EX/MEM/WB ve ID Stage
    // Chi can forward fwd_data_ex tu EX stage vi MUL/DIV/CSR da duoc Hazard Unit stall
    // Ngan chan triet de critical path 23ns qua DSP48E1 vao Branch Comparator & Branch Predictor
    assign branch_src_a = (ctrl_reg_write_ex && (rd_addr_ex != 5'b0) && (rd_addr_ex == rs1_addr_id)) ? fwd_data_ex :
                          (ctrl_reg_write_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs1_addr_id)) ? fwd_data_mem :
                          (ctrl_reg_write_wb && (rd_addr_wb != 5'b0) && (rd_addr_wb == rs1_addr_id)) ? wb_final_data :
                          rs1_data_id;

    assign branch_src_b = (ctrl_reg_write_ex && (rd_addr_ex != 5'b0) && (rd_addr_ex == rs2_addr_id)) ? fwd_data_ex :
                          (ctrl_reg_write_mem && (rd_addr_mem != 5'b0) && (rd_addr_mem == rs2_addr_id)) ? fwd_data_mem :
                          (ctrl_reg_write_wb && (rd_addr_wb != 5'b0) && (rd_addr_wb == rs2_addr_id)) ? wb_final_data :
                          rs2_data_id;

    branch_comp branch_comparator (
        .i_src_a  (branch_src_a),
        .i_src_b  (branch_src_b),
        .o_br_eq  (br_eq),
        .o_br_lt  (br_lt),
        .o_br_ltu (br_ltu)
    );

    // Xu ly dieu kien Branch
    always @(*) begin
        case (funct3_id)
            `FUNCT3_BEQ:  branch_taken = ctrl_branch && br_eq;
            `FUNCT3_BNE:  branch_taken = ctrl_branch && !br_eq;
            `FUNCT3_BLT:  branch_taken = ctrl_branch && br_lt;
            `FUNCT3_BGE:  branch_taken = ctrl_branch && !br_lt;
            `FUNCT3_BLTU: branch_taken = ctrl_branch && br_ltu;
            `FUNCT3_BGEU: branch_taken = ctrl_branch && !br_ltu;
            default:      branch_taken = 1'b0;
        endcase
    end

    assign branch_target = pc_id + imm_ext_id;
    assign jump_target   = pc_id + imm_ext_id;
    assign jalr_target   = (branch_src_a + imm_ext_id) & ~32'd1;

    // Logic kiem tra Misprediction cua Branch Predictor:
    // 1. Sai huong re nhanh (Taken vs Not-Taken)
    // 2. Sai dia chi dich khi Taken (BTB Target mismatch)
    assign branch_mispredict = ctrl_branch && ((branch_taken != pred_taken_id) || 
                                               (branch_taken && (branch_target != pred_target_id)));

    // Dia chi sua sai: neu actual taken thi nhay branch_target, nguoc lai fall-through ve pc_id + 4
    assign branch_correct_pc = branch_taken ? branch_target : (pc_id + 32'd4);

    // Huan luyen Branch Predictor tai ID Stage
    assign bp_update_en     = !pipeline_hold && (ctrl_branch || ctrl_jump);
    assign bp_update_pc     = pc_id;
    assign bp_update_taken  = ctrl_jump ? 1'b1 : branch_taken;
    assign bp_update_target = ctrl_jump ? jump_target : branch_target;

    hazard_unit hazard (
        .i_id_ex_mem_read    (ctrl_mem_req_read_ex),
        .i_id_ex_rd          (rd_addr_ex),
        .i_if_id_rs1         (rs1_addr_id),
        .i_if_id_rs2         (rs2_addr_id),
        .i_uses_rs1          (ctrl_uses_rs1),
        .i_uses_rs2          (ctrl_uses_rs2),
        .i_branch_mispredict (branch_mispredict),
        .i_jump_taken        (ctrl_jump_reg || (ctrl_jump && !pred_taken_id)),
        .i_mret              (ctrl_mret),
        .i_trap_taken        (trap_taken),
        .i_axi_i_stall       (i_axi_i_stall),
        .i_axi_d_stall       (i_axi_d_stall),
        .i_div_busy          (div_busy),
        .i_id_ex_is_mul      (ctrl_is_mul_ex),
        .i_branch            (ctrl_branch),
        .i_id_ex_is_csr      (ctrl_wb_src_ex == `WB_SRC_CSR),
        .i_ex_mem_is_csr     (ctrl_wb_src_mem == `WB_SRC_CSR),
        .i_ex_mem_rd         (rd_addr_mem),
        .o_pc_write          (pc_write),
        .o_if_id_write       (if_id_write),
        .o_if_id_flush       (if_id_flush),
        .o_id_ex_flush       (id_ex_flush),
        .o_pipeline_hold     (pipeline_hold),
        .o_id_ex_hold        (id_ex_hold),
        .o_ex_mem_flush      (ex_mem_flush),
        .o_hazard_stall      (hazard_stall)
    );

    id_ex_reg ID_EX (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_hold          (pipeline_hold || id_ex_hold),
        .i_flush         (id_ex_flush),
        .i_reg_write     (ctrl_reg_write),
        .i_wb_src        (ctrl_wb_src),
        .i_alu_src_a     (ctrl_alu_src_a),
        .i_alu_src_b     (ctrl_alu_src_b),
        .i_alu_op        (ctrl_alu_op),
        .i_mem_req_read  (ctrl_mem_req_read),
        .i_mem_req_write (ctrl_mem_req_write),
        .i_csr_op        (ctrl_csr_op),
        .i_ecall_halt    (ctrl_ecall_halt),
        .i_is_mul        (ctrl_is_mul),
        .i_is_div        (ctrl_is_div),
        .i_pc            (pc_id),
        .i_rs1_data      (rs1_data_id),
        .i_rs2_data      (rs2_data_id),
        .i_imm_ext       (imm_ext_id),
        .i_rs1_addr      (rs1_addr_id),
        .i_rs2_addr      (rs2_addr_id),
        .i_rd_addr       (rd_addr_id),
        .i_funct3        (funct3_id),
        .i_csr_addr      (csr_addr_id),

        .o_reg_write     (ctrl_reg_write_ex),
        .o_wb_src        (ctrl_wb_src_ex),
        .o_alu_src_a     (ctrl_alu_src_a_ex),
        .o_alu_src_b     (ctrl_alu_src_b_ex),
        .o_alu_op        (ctrl_alu_op_ex),
        .o_mem_req_read  (ctrl_mem_req_read_ex),
        .o_mem_req_write (ctrl_mem_req_write_ex),
        .o_csr_op        (ctrl_csr_op_ex),
        .o_ecall_halt    (ctrl_ecall_halt_ex),
        .o_is_mul        (ctrl_is_mul_ex),
        .o_is_div        (ctrl_is_div_ex),
        .o_pc            (pc_ex),
        .o_rs1_data      (rs1_data_ex),
        .o_rs2_data      (rs2_data_ex),
        .o_imm_ext       (imm_ext_ex),
        .o_rs1_addr      (rs1_addr_ex),
        .o_rs2_addr      (rs2_addr_ex),
        .o_rd_addr       (rd_addr_ex),
        .o_funct3        (funct3_ex),
        .o_csr_addr      (csr_addr_ex)
    );

    // =========================================================================
    // 3. EX STAGE (EXECUTE: ALU + RV32M MULTIPLIER + MULTI-CYCLE DIVIDER)
    // =========================================================================
    forwarding_unit fwd_unit (
        .i_id_ex_rs1        (rs1_addr_ex),
        .i_id_ex_rs2        (rs2_addr_ex),
        .i_ex_mem_rd        (rd_addr_mem),
        .i_ex_mem_reg_write (ctrl_reg_write_mem),
        .i_mem_wb_rd        (rd_addr_wb),
        .i_mem_wb_reg_write (ctrl_reg_write_wb),
        .o_forward_a        (forward_a),
        .o_forward_b        (forward_b)
    );

    // Forwarding tu MEM stage lay dung du lieu fwd_data_mem
    assign alu_in_a_raw = (forward_a == 2'b10) ? fwd_data_mem :
                          (forward_a == 2'b01) ? wb_final_data :
                          rs1_data_ex;

    assign alu_in_b_raw = (forward_b == 2'b10) ? fwd_data_mem :
                          (forward_b == 2'b01) ? wb_final_data :
                          rs2_data_ex;

    assign alu_in_a = ctrl_alu_src_a_ex ? pc_ex : alu_in_a_raw;
    assign alu_in_b = ctrl_alu_src_b_ex ? imm_ext_ex : alu_in_b_raw;

    // Standard RV32I ALU
    alu alu_inst (
        .i_in_a    (alu_in_a),
        .i_in_b    (alu_in_b),
        .i_alu_op  (ctrl_alu_op_ex),
        .o_result  (alu_result_ex),
        .o_zero    ()
    );

    // RV32M Hardware Multiplier (DSP-Mapped, Single-Cycle)
    multiplier mul_inst (
        .i_a      (alu_in_a),
        .i_b      (alu_in_b),
        .i_funct3 (funct3_ex),
        .o_result (mul_result_ex)
    );

    // RV32M Hardware Divider (32-Cycle Shift-Subtract / Fast-Exit)
    divider div_inst (
        .i_clk      (i_clk),
        .i_rst_n    (i_rst_n),
        .i_start    (ctrl_is_div_ex),
        .i_funct3   (funct3_ex),
        .i_dividend (alu_in_a),
        .i_divisor  (alu_in_b),
        .o_result   (div_result_ex),
        .o_busy     (div_busy),
        .o_done     (div_done)
    );

    // Chon ket qua EX Stage: Multiplier > Divider > ALU
    assign ex_final_result = ctrl_is_mul_ex ? mul_result_ex :
                             ctrl_is_div_ex ? div_result_ex :
                                              alu_result_ex;

    // Ho tro ca CSR thanh ghi (CSRRW/CSRRS/CSRRC) va CSR hang so 5-bit zimm (CSRRWI/CSRRSI/CSRRCI)
    wire [DATA_WIDTH-1:0] csr_wdata_ex = funct3_ex[2] ? {27'd0, rs1_addr_ex} : alu_in_a_raw;

    ex_mem_reg EX_MEM (
        .i_clk           (i_clk),
        .i_rst_n         (i_rst_n),
        .i_hold          (pipeline_hold),
        .i_flush         (ex_mem_flush),
        .i_reg_write     (ctrl_reg_write_ex),
        .i_wb_src        (ctrl_wb_src_ex),
        .i_mem_req_read  (ctrl_mem_req_read_ex),
        .i_mem_req_write (ctrl_mem_req_write_ex),
        .i_csr_op        (ctrl_csr_op_ex),
        .i_ecall_halt    (ctrl_ecall_halt_ex),
        .i_pc            (pc_ex),
        .i_alu_result    (ex_final_result),
        .i_rs2_data      (alu_in_b_raw),
        .i_rd_addr       (rd_addr_ex),
        .i_funct3        (funct3_ex),
        .i_csr_addr      (csr_addr_ex),
        .i_csr_wdata     (csr_wdata_ex),

        .o_reg_write     (ctrl_reg_write_mem),
        .o_wb_src        (ctrl_wb_src_mem),
        .o_mem_req_read  (ctrl_mem_req_read_mem),
        .o_mem_req_write (ctrl_mem_req_write_mem),
        .o_csr_op        (ctrl_csr_op_mem),
        .o_ecall_halt    (ctrl_ecall_halt_mem),
        .o_pc            (pc_mem),
        .o_alu_result    (alu_result_mem),
        .o_rs2_data      (rs2_data_mem),
        .o_rd_addr       (rd_addr_mem),
        .o_funct3        (funct3_mem),
        .o_csr_addr      (csr_addr_mem),
        .o_csr_wdata     (csr_wdata_mem)
    );

    // =========================================================================
    // 4. MEM STAGE (MEMORY ACCESS)
    // =========================================================================
    assign o_dmem_addr      = alu_result_mem;
    assign o_dmem_wdata     = rs2_data_mem;
    assign o_dmem_funct3    = funct3_mem;
    assign o_dmem_req_read  = ctrl_mem_req_read_mem;
    assign o_dmem_req_write = ctrl_mem_req_write_mem;

    mem_wb_reg MEM_WB (
        .i_clk        (i_clk),
        .i_rst_n      (i_rst_n),
        .i_hold       (pipeline_hold),
        .i_reg_write  (ctrl_reg_write_mem),
        .i_wb_src     (ctrl_wb_src_mem),
        .i_csr_op     (ctrl_csr_op_mem),
        .i_ecall_halt (ctrl_ecall_halt_mem),
        .i_pc         (pc_mem),
        .i_mem_rdata  (i_dmem_rdata),
        .i_alu_result (alu_result_mem),
        .i_rd_addr    (rd_addr_mem),
        .i_csr_addr   (csr_addr_mem),
        .i_csr_wdata  (csr_wdata_mem),

        .o_reg_write  (ctrl_reg_write_wb),
        .o_wb_src     (ctrl_wb_src_wb),
        .o_csr_op     (ctrl_csr_op_wb),
        .o_ecall_halt (ctrl_ecall_halt_wb),
        .o_pc         (pc_wb),
        .o_mem_rdata  (mem_rdata_wb),
        .o_alu_result (alu_result_wb),
        .o_rd_addr    (rd_addr_wb),
        .o_csr_addr   (csr_addr_wb),
        .o_csr_wdata  (csr_wdata_wb)
    );

    // =========================================================================
    // 5. WB STAGE (WRITE BACK & CSR INTEGRATION)
    // =========================================================================
    csr_file csr_inst (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_csr_addr         (csr_addr_wb),
        .i_csr_wdata        (csr_wdata_wb),
        .i_csr_op           (ctrl_csr_op_wb),
        .o_csr_rdata        (csr_rdata_wb),
        .i_inst_ret_valid   (!pipeline_hold && (ctrl_reg_write_wb || ctrl_mem_req_write_mem || (ctrl_csr_op_wb != 2'b00) || ctrl_ecall_halt_wb)),
        .i_timer_irq        (i_timer_irq),
        .i_external_irq     (i_external_irq),
        .i_trap_taken       (trap_taken),
        .i_trap_pc          (trap_save_pc),
        .i_trap_cause       (trap_irq_cause),
        .i_mret             (ctrl_mret && !pipeline_hold),
        .o_trap_irq_req     (trap_irq_req),
        .o_trap_target_pc   (trap_target_pc),
        .o_mepc_val         (mepc_val),
        .o_trap_irq_cause   (trap_irq_cause)
    );

    // Chon nguon du lieu ghi ve Register File (WB MUX)
    // Ho tro day du: ALU Result, Memory Load Data, PC + 4 (JAL/JALR), CSR Read Data
    assign wb_final_data = (ctrl_wb_src_wb == `WB_SRC_MEM)      ? mem_rdata_wb :
                           (ctrl_wb_src_wb == `WB_SRC_PC_PLUS4)  ? (pc_wb + 32'd4) :
                           (ctrl_wb_src_wb == `WB_SRC_CSR)      ? csr_rdata_wb :
                                                                  alu_result_wb;

    assign o_ecall_halt = ctrl_ecall_halt_wb;

endmodule
