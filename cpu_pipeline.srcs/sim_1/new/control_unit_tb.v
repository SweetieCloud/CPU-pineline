`timescale 1ns / 1ps
`include "defines.vh"

module control_unit_tb;

    reg  [6:0]  opcode;
    reg  [2:0]  funct3;
    reg  [6:0]  funct7;
    reg  [11:0] funct12;

    wire        reg_write;
    wire [1:0]  wb_src;
    wire        alu_src_a;
    wire        alu_src_b;
    wire [2:0]  imm_src;
    wire [3:0]  alu_op;
    wire        branch;
    wire        jump;
    wire        jump_reg;
    wire        mem_req_read;
    wire        mem_req_write;
    wire [1:0]  csr_op;
    wire        ecall_halt;
    wire        mret;
    wire        uses_rs1;
    wire        uses_rs2;
    wire        is_mul;
    wire        is_div;
    wire        icache_inv;

    control_unit uut (
        .i_opcode       (opcode),
        .i_funct3       (funct3),
        .i_funct7       (funct7),
        .i_funct12      (funct12),
        .o_reg_write    (reg_write),
        .o_wb_src       (wb_src),
        .o_alu_src_a    (alu_src_a),
        .o_alu_src_b    (alu_src_b),
        .o_imm_src      (imm_src),
        .o_alu_op       (alu_op),
        .o_branch       (branch),
        .o_jump         (jump),
        .o_jump_reg     (jump_reg),
        .o_mem_req_read (mem_req_read),
        .o_mem_req_write(mem_req_write),
        .o_csr_op       (csr_op),
        .o_ecall_halt   (ecall_halt),
        .o_mret         (mret),
        .o_uses_rs1     (uses_rs1),
        .o_uses_rs2     (uses_rs2),
        .o_is_mul       (is_mul),
        .o_is_div       (is_div),
        .o_icache_inv   (icache_inv)
    );

    task apply_inst;
        input [6:0]  op;
        input [2:0]  f3;
        input [6:0]  f7;
        input [11:0] f12;
        begin
            opcode  = op;
            funct3  = f3;
            funct7  = f7;
            funct12 = f12;
            #10;
        end
    endtask

    initial begin
        $display("\n============================================================");
        $display("   STARTING CONTROL_UNIT FULL OP/BRANCH COVERAGE SUITE");
        $display("============================================================\n");

        // 1. R-Type (RV32I): funct3 0..7
        apply_inst(`OPCODE_OP, 3'b000, 7'b0000000, 12'h0); // ADD
        apply_inst(`OPCODE_OP, 3'b000, 7'b0100000, 12'h0); // SUB
        apply_inst(`OPCODE_OP, 3'b001, 7'b0000000, 12'h0); // SLL
        apply_inst(`OPCODE_OP, 3'b010, 7'b0000000, 12'h0); // SLT
        apply_inst(`OPCODE_OP, 3'b011, 7'b0000000, 12'h0); // SLTU
        apply_inst(`OPCODE_OP, 3'b100, 7'b0000000, 12'h0); // XOR
        apply_inst(`OPCODE_OP, 3'b101, 7'b0000000, 12'h0); // SRL
        apply_inst(`OPCODE_OP, 3'b101, 7'b0100000, 12'h0); // SRA
        apply_inst(`OPCODE_OP, 3'b110, 7'b0000000, 12'h0); // OR
        apply_inst(`OPCODE_OP, 3'b111, 7'b0000000, 12'h0); // AND

        // 2. M-Extension (RV32M)
        apply_inst(`OPCODE_OP, `FUNCT3_MUL,    `FUNCT7_M_EXT, 12'h0); // MUL
        apply_inst(`OPCODE_OP, `FUNCT3_MULH,   `FUNCT7_M_EXT, 12'h0); // MULH
        apply_inst(`OPCODE_OP, `FUNCT3_MULHSU, `FUNCT7_M_EXT, 12'h0); // MULHSU
        apply_inst(`OPCODE_OP, `FUNCT3_MULHU,  `FUNCT7_M_EXT, 12'h0); // MULHU
        apply_inst(`OPCODE_OP, `FUNCT3_DIV,    `FUNCT7_M_EXT, 12'h0); // DIV
        apply_inst(`OPCODE_OP, `FUNCT3_DIVU,   `FUNCT7_M_EXT, 12'h0); // DIVU
        apply_inst(`OPCODE_OP, `FUNCT3_REM,    `FUNCT7_M_EXT, 12'h0); // REM
        apply_inst(`OPCODE_OP, `FUNCT3_REMU,   `FUNCT7_M_EXT, 12'h0); // REMU

        // 3. I-Type Arithmetic: funct3 0..7
        apply_inst(`OPCODE_OP_IMM, 3'b000, 7'b0000000, 12'h0); // ADDI
        apply_inst(`OPCODE_OP_IMM, 3'b010, 7'b0000000, 12'h0); // SLTI
        apply_inst(`OPCODE_OP_IMM, 3'b011, 7'b0000000, 12'h0); // SLTIU
        apply_inst(`OPCODE_OP_IMM, 3'b100, 7'b0000000, 12'h0); // XORI
        apply_inst(`OPCODE_OP_IMM, 3'b110, 7'b0000000, 12'h0); // ORI
        apply_inst(`OPCODE_OP_IMM, 3'b111, 7'b0000000, 12'h0); // ANDI
        apply_inst(`OPCODE_OP_IMM, 3'b001, 7'b0000000, 12'h0); // SLLI
        apply_inst(`OPCODE_OP_IMM, 3'b101, 7'b0000000, 12'h0); // SRLI
        apply_inst(`OPCODE_OP_IMM, 3'b101, 7'b0100000, 12'h0); // SRAI

        // 4. Load & Store
        apply_inst(`OPCODE_LOAD,  `FUNCT3_LW, 7'b0, 12'h0); // LW
        apply_inst(`OPCODE_STORE, `FUNCT3_SW, 7'b0, 12'h0); // SW

        // 5. Branch
        apply_inst(`OPCODE_BRANCH, `FUNCT3_BEQ, 7'b0, 12'h0); // BEQ

        // 6. Jumps & Upper Immediates
        apply_inst(`OPCODE_JAL,   3'b0, 7'b0, 12'h0); // JAL
        apply_inst(`OPCODE_JALR,  3'b0, 7'b0, 12'h0); // JALR
        apply_inst(`OPCODE_LUI,   3'b0, 7'b0, 12'h0); // LUI
        apply_inst(`OPCODE_AUIPC, 3'b0, 7'b0, 12'h0); // AUIPC

        // 7. FENCE & FENCE.I
        apply_inst(`OPCODE_MISC_MEM, 3'b001, 7'b0, 12'h0); // FENCE.I
        apply_inst(`OPCODE_MISC_MEM, 3'b000, 7'b0, 12'h0); // FENCE

        // 8. System & CSR & Trap
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRW,  7'b0, 12'h0);   // CSRRW
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRS,  7'b0, 12'h0);   // CSRRS
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRC,  7'b0, 12'h0);   // CSRRC
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRWI, 7'b0, 12'h0);   // CSRRWI
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRSI, 7'b0, 12'h0);   // CSRRSI
        apply_inst(`OPCODE_SYSTEM, `FUNCT3_CSRRCI, 7'b0, 12'h0);   // CSRRCI
        apply_inst(`OPCODE_SYSTEM, 3'b000,         7'b0, 12'h000); // ECALL
        apply_inst(`OPCODE_SYSTEM, 3'b000,         7'b0, 12'h001); // EBREAK
        apply_inst(`OPCODE_SYSTEM, 3'b000,         7'b0, 12'h302); // MRET
        apply_inst(`OPCODE_SYSTEM, 3'b000,         7'b0, 12'hFFF); // Other system

        // 9. Default / Illegal Opcode
        apply_inst(7'b0000000, 3'b0, 7'b0, 12'h0); // Default

        $display("\n============================================================");
        $display("   CONTROL_UNIT VERIFICATION FINISHED: ALL PATTERNS APPLIED");
        $display("============================================================\n");
        $finish;
    end

endmodule
