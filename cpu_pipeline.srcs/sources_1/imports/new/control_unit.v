`timescale 1ns / 1ps
`include "defines.vh"

module control_unit (
    input  wire [6:0]  i_opcode,
    input  wire [2:0]  i_funct3,
    input  wire [6:0]  i_funct7,
    input  wire [11:0] i_funct12,

    // Tin hieu dieu khien Register File & Datapath
    output reg        o_reg_write,
    output reg [1:0]  o_wb_src,        // 00: ALU, 01: Mem, 10: PC+4, 11: CSR
    output reg        o_alu_src_a,     // 0: RS1, 1: PC (cho AUIPC)
    output reg        o_alu_src_b,     // 0: RS2, 1: Immediate
    output reg [2:0]  o_imm_src,       // Kieu mo rong hang so
    output reg [3:0]  o_alu_op,        // Ma phep toan ALU

    // Tin hieu dieu khien Re nhanh / Nhay
    output reg        o_branch,        // Tin hieu re nhanh co dieu kien
    output reg        o_jump,          // Nhay khong dieu kien JAL
    output reg        o_jump_reg,      // Nhay qua thanh ghi JALR

    // Tin hieu giao tiep Bo nho / Bus
    output reg        o_mem_req_read,
    output reg        o_mem_req_write,

    // Tin hieu CSR & He thong
    output reg [1:0]  o_csr_op,        // 00: None, 01: Write, 10: Set, 11: Clear
    output reg        o_ecall_halt,    // Tin hieu dung mo phong / bao su kien he thong
    output reg        o_mret,          // Lenh quay ve tu Trap (MRET)

    // Tin hieu bao thanh ghi nguon duoc su dung (chong False Stall trong Hazard Unit)
    output reg        o_uses_rs1,
    output reg        o_uses_rs2,

    // Tin hieu dieu khien M-extension (RV32M Multiplier / Divider)
    output reg        o_is_mul,
    output reg        o_is_div,

    // Tin hieu dong bo Cache (FENCE.I)
    output reg        o_icache_inv
);

    always @(*) begin
        // ---------------------------------------------------------------------
        // GIA TRI MAC DINH (TRANH SINH LATCH)
        // ---------------------------------------------------------------------
        o_reg_write     = 1'b0;
        o_wb_src        = `WB_SRC_ALU;
        o_alu_src_a     = 1'b0;
        o_alu_src_b     = 1'b0;
        o_imm_src       = `IMM_I;
        o_alu_op        = `ALU_ADD;
        o_branch        = 1'b0;
        o_jump          = 1'b0;
        o_jump_reg      = 1'b0;
        o_mem_req_read  = 1'b0;
        o_mem_req_write = 1'b0;
        o_csr_op        = 2'b00;
        o_ecall_halt    = 1'b0;
        o_mret          = 1'b0;
        o_uses_rs1      = 1'b0;
        o_uses_rs2      = 1'b0;
        o_is_mul        = 1'b0;
        o_is_div        = 1'b0;
        o_icache_inv    = 1'b0;

        // ---------------------------------------------------------------------
        // GIAI MA TAP LENH RV32I / RV32M
        // ---------------------------------------------------------------------
        case (i_opcode)
            `OPCODE_OP: begin // R-Type ALU hoac RV32M
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_ALU;
                o_alu_src_a = 1'b0;
                o_alu_src_b = 1'b0;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b1;

                if (i_funct7 == `FUNCT7_M_EXT) begin
                    // RV32M Extension (funct3[2] = 0: MUL*, funct3[2] = 1: DIV*/REM*)
                    if (i_funct3[2]) begin
                        o_is_div = 1'b1;
                    end else begin
                        o_is_mul = 1'b1;
                    end
                end else begin
                    case (i_funct3)
                        3'b000:  o_alu_op = (i_funct7[5]) ? `ALU_SUB : `ALU_ADD; // SUB / ADD
                        3'b001:  o_alu_op = `ALU_SLL;  // SLL
                        3'b010:  o_alu_op = `ALU_SLT;  // SLT
                        3'b011:  o_alu_op = `ALU_SLTU; // SLTU
                        3'b100:  o_alu_op = `ALU_XOR;  // XOR
                        3'b101:  o_alu_op = (i_funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRA / SRL
                        3'b110:  o_alu_op = `ALU_OR;   // OR
                        3'b111:  o_alu_op = `ALU_AND;  // AND
                        default: o_alu_op = `ALU_ADD;
                    endcase
                end
            end

            `OPCODE_OP_IMM: begin // I-Type ALU (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_ALU;
                o_alu_src_a = 1'b0;
                o_alu_src_b = 1'b1;
                o_imm_src   = `IMM_I;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b0; // Khong dung RS2!

                case (i_funct3)
                    3'b000:  o_alu_op = `ALU_ADD;  // ADDI
                    3'b001:  o_alu_op = `ALU_SLL;  // SLLI
                    3'b010:  o_alu_op = `ALU_SLT;  // SLTI
                    3'b011:  o_alu_op = `ALU_SLTU; // SLTIU
                    3'b100:  o_alu_op = `ALU_XOR;  // XORI
                    3'b101:  o_alu_op = (i_funct7[5]) ? `ALU_SRA : `ALU_SRL; // SRAI / SRLI
                    3'b110:  o_alu_op = `ALU_OR;   // ORI
                    3'b111:  o_alu_op = `ALU_AND;  // ANDI
                    default: o_alu_op = `ALU_ADD;
                endcase
            end

            `OPCODE_LOAD: begin // Load (LB, LH, LW, LBU, LHU)
                o_reg_write    = 1'b1;
                o_wb_src       = `WB_SRC_MEM;
                o_alu_src_a    = 1'b0;
                o_alu_src_b    = 1'b1;
                o_imm_src      = `IMM_I;
                o_alu_op       = `ALU_ADD;
                o_mem_req_read = 1'b1;
                o_uses_rs1     = 1'b1;
                o_uses_rs2     = 1'b0; // Khong dung RS2!
            end

            `OPCODE_STORE: begin // Store (SB, SH, SW)
                o_reg_write     = 1'b0;
                o_alu_src_a     = 1'b0;
                o_alu_src_b     = 1'b1;
                o_imm_src       = `IMM_S;
                o_alu_op        = `ALU_ADD;
                o_mem_req_write = 1'b1;
                o_uses_rs1      = 1'b1;
                o_uses_rs2      = 1'b1; // RS2 la du lieu can ghi vao bo nho
            end

            `OPCODE_BRANCH: begin // Branch (BEQ, BNE, BLT, BGE, BLTU, BGEU)
                o_reg_write = 1'b0;
                o_branch    = 1'b1;
                o_imm_src   = `IMM_B;
                o_alu_op    = `ALU_SUB;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b1;
            end

            `OPCODE_LUI: begin // U-Type LUI (Load Upper Immediate)
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_ALU;
                o_alu_src_a = 1'b0;
                o_alu_src_b = 1'b1;
                o_imm_src   = `IMM_U;
                o_alu_op    = `ALU_COPY_B;
                o_uses_rs1  = 1'b0;
                o_uses_rs2  = 1'b0;
            end

            `OPCODE_AUIPC: begin // U-Type AUIPC (Add Upper Immediate to PC)
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_ALU;
                o_alu_src_a = 1'b1; // Chon toan hang A tu PC
                o_alu_src_b = 1'b1; // Chon toan hang B tu Immediate
                o_imm_src   = `IMM_U;
                o_alu_op    = `ALU_ADD;
                o_uses_rs1  = 1'b0;
                o_uses_rs2  = 1'b0;
            end

            `OPCODE_JAL: begin // J-Type JAL (Jump and Link)
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_PC_PLUS4; // Luu PC+4 vao thanh ghi rd!
                o_jump      = 1'b1;
                o_imm_src   = `IMM_J;
                o_uses_rs1  = 1'b0;
                o_uses_rs2  = 1'b0;
            end

            `OPCODE_JALR: begin // I-Type JALR (Jump and Link Register)
                o_reg_write = 1'b1;
                o_wb_src    = `WB_SRC_PC_PLUS4; // Luu PC+4 vao thanh ghi rd!
                o_jump_reg  = 1'b1;
                o_alu_src_a = 1'b0;
                o_alu_src_b = 1'b1;
                o_imm_src   = `IMM_I;
                o_alu_op    = `ALU_ADD;
                o_uses_rs1  = 1'b1;
                o_uses_rs2  = 1'b0;
            end

            `OPCODE_MISC_MEM: begin // FENCE (000) & FENCE.I (001)
                if (i_funct3 == 3'b001) begin
                    o_icache_inv = 1'b1; // FENCE.I: Xoa sach L1 Instruction Cache
                end
            end

            `OPCODE_SYSTEM: begin // CSR & ECALL/EBREAK/MRET
                case (i_funct3)
                    3'b000: begin
                        if (i_funct12 == 12'h302) begin
                            o_mret       = 1'b1; // MRET (Return from Machine Mode Trap)
                            o_ecall_halt = 1'b0;
                        end else begin
                            o_mret       = 1'b0;
                            o_ecall_halt = 1'b1; // ECALL / EBREAK
                        end
                    end
                    `FUNCT3_CSRRW: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b01; // CSR Write
                        o_uses_rs1  = 1'b1;
                    end
                    `FUNCT3_CSRRS: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b10; // CSR Bit Set
                        o_uses_rs1  = 1'b1;
                    end
                    `FUNCT3_CSRRC: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b11; // CSR Bit Clear
                        o_uses_rs1  = 1'b1;
                    end
                    `FUNCT3_CSRRWI: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b01; // CSR Write Immediate (zimm[4:0])
                        o_uses_rs1  = 1'b0;
                    end
                    `FUNCT3_CSRRSI: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b10; // CSR Bit Set Immediate (zimm[4:0])
                        o_uses_rs1  = 1'b0;
                    end
                    `FUNCT3_CSRRCI: begin
                        o_reg_write = 1'b1;
                        o_wb_src    = `WB_SRC_CSR;
                        o_csr_op    = 2'b11; // CSR Bit Clear Immediate (zimm[4:0])
                        o_uses_rs1  = 1'b0;
                    end
                    default: ;
                endcase
            end

            default: ;
        endcase
    end

endmodule
