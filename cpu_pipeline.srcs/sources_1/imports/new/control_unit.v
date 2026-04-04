/* * File: control_unit.v
 */
`timescale 1ns / 1ps

module control_unit(
    input [3:0] opcode,
    input [2:0] funct,
    
    // --- Control Signals ---
    output reg RegWrite,
    output reg MemtoReg,    // 0=ALU, 1=Mem
    output reg MemRead,
    output reg MemWrite,
    output reg ALUSrc,      // 0=Reg, 1=Imm
    output reg RegDst,      // 0=$rt, 1=$rd
    output reg Branch,      // 1=Lá»‡nh Branch (BNEQ, BGTZ)
    output reg Jump,        // 1=Lá»‡nh Jump
    output reg [4:0] ALUOp,
    output reg JumpReg,
    output reg HILO_WriteEn,
    output reg MTSR_WriteEn,
    output reg MFSR_ReadEn,
    output reg IsBGTZ,
    output reg Halt
);

    // --- ALU OP CODES ---
    parameter OP_ADD       = 5'b00001;
    parameter OP_ADDU      = 5'b00010;
    parameter OP_SUB       = 5'b00011;
    parameter OP_SUBU      = 5'b00100;
    parameter OP_AND       = 5'b00101;
    parameter OP_OR        = 5'b00110;
    parameter OP_NOR       = 5'b00111;
    parameter OP_XOR       = 5'b01000;
    parameter OP_SLT       = 5'b01001;
    parameter OP_SLTU      = 5'b01010;
    parameter OP_SEQ       = 5'b01011;
    parameter OP_SHR       = 5'b01100;
    parameter OP_SHL       = 5'b01101;
    parameter OP_ROR       = 5'b01110;
    parameter OP_ROL       = 5'b01111;
    parameter OP_MULT      = 5'b10000;
    parameter OP_MULTU     = 5'b10001;
    parameter OP_DIV       = 5'b10010;
    parameter OP_DIVU      = 5'b10011;
    parameter OP_ADDR_CALC = 5'b10100; 

    always @(*) begin
        RegWrite     = 0;
        MemtoReg     = 0;
        MemRead      = 0;
        MemWrite     = 0;
        ALUSrc       = 0;
        RegDst       = 0;
        Branch       = 0;
        Jump         = 0;
        JumpReg      = 0;
        ALUOp        = 5'b00000;
        HILO_WriteEn = 0;
        MTSR_WriteEn = 0;
        MFSR_ReadEn  = 0;
        IsBGTZ       = 0;
        Halt = 0;

        // Main Decoding
        case (opcode)
            4'b0000: begin // ALU0 (R-Type)
                RegWrite = 1;
                RegDst   = 1; 
                ALUSrc   = 0;
 
                case(funct)
                    3'b000: ALUOp = OP_ADDU;
                    3'b001: ALUOp = OP_SUBU;
                    3'b010: begin ALUOp = OP_MULTU; HILO_WriteEn = 1; end
                    3'b011: begin ALUOp = OP_DIVU;  HILO_WriteEn = 1; end
                    3'b100: ALUOp = OP_AND;
                    3'b101: ALUOp = OP_OR;
                    3'b110: ALUOp = OP_NOR;
                    3'b111: ALUOp = OP_XOR;
                endcase
            end
            
            4'b0001: begin // ALU1 (R-Type)
                ALUSrc = 0;
                RegDst = 1;
                case(funct)
                    3'b000: begin ALUOp = OP_ADD; RegWrite = 1; end
                    3'b001: begin ALUOp = OP_SUB; RegWrite = 1; end
                    3'b010: begin ALUOp = OP_MULT; HILO_WriteEn = 1; RegWrite = 1; end
                    3'b011: begin ALUOp = OP_DIV;  HILO_WriteEn = 1; RegWrite = 1; end
                    3'b100: begin ALUOp = OP_SLT; RegWrite = 1; end
                    3'b101: begin ALUOp = OP_SEQ; RegWrite = 1; end
                    3'b110: begin ALUOp = OP_SLTU; RegWrite = 1; end
                    3'b111: begin // jr $rs
                         JumpReg = 1;
                    end
                endcase
            end
            
            4'b0010: begin // ALU2 (Shift - R-Type)
                RegWrite = 1;
                RegDst   = 1;
                ALUSrc   = 0;
                case(funct)
                    3'b000: ALUOp = OP_SHR;
                    3'b001: ALUOp = OP_SHL;
                    3'b010: ALUOp = OP_ROR;
                    3'b011: ALUOp = OP_ROL;
                endcase
            end
            
            4'b0011: begin // ADDI
                RegWrite = 1;
                RegDst   = 0;  
                ALUSrc   = 1;  
                ALUOp    = OP_ADDU; 
            end
            
            4'b0100: begin // SLTI
                RegWrite = 1;
                RegDst   = 0;
                ALUSrc   = 1;
                ALUOp    = OP_SLT;
            end
            
            4'b0101: begin // BNEQ
                Branch   = 1;
                ALUSrc   = 0;
                ALUOp    = OP_SUBU;  
            end
            
            4'b0110: begin // BGTZ
                Branch   = 1;
                IsBGTZ   = 1;
                ALUSrc   = 0; // Check $rs
                ALUOp    = OP_SUBU;  
            end
            
            4'b0111: begin // JUMP
                Jump     = 1;
            end
            
            4'b1000: begin // LH
                RegWrite = 1;
                RegDst   = 0;
                ALUSrc   = 1;
                MemRead  = 1;
                MemtoReg = 1;  
                ALUOp    = OP_ADDR_CALC;  
            end
            
            4'b1001: begin // SH
                MemWrite = 1;
                ALUSrc   = 1;
                ALUOp    = OP_ADDR_CALC;  
            end
            
            4'b1010: begin // MFSR
                RegWrite    = 1;
                RegDst      = 1;
                MFSR_ReadEn = 1;
            end
            
            4'b1011: begin // MTSR
                MTSR_WriteEn = 1;
            end
            
            4'b1111: begin // HLT
                Halt = 1;
                RegWrite = 0;
                MemWrite = 0;
            end
        endcase
    end
endmodule 
