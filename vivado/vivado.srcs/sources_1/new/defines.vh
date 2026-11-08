`ifndef DEFINES_VH
`define DEFINES_VH

// =============================================================================
// THONG SO CAU HINH HE THONG (32-BIT RISC-V)
// =============================================================================
`define DATA_WIDTH      32
`define ADDR_WIDTH      32
`define REG_ADDR_WIDTH  5
`define REG_NUM         32

// =============================================================================
// MA OPCODE CHUAN RV32I (instr[6:0])
// =============================================================================
`define OPCODE_LUI      7'b0110111
`define OPCODE_AUIPC    7'b0010111
`define OPCODE_JAL      7'b1101111
`define OPCODE_JALR     7'b1100111
`define OPCODE_BRANCH   7'b1100011
`define OPCODE_LOAD     7'b0000011
`define OPCODE_STORE    7'b0100011
`define OPCODE_OP_IMM   7'b0010011
`define OPCODE_OP       7'b0110011
`define OPCODE_MISC_MEM 7'b0001111
`define OPCODE_SYSTEM   7'b1110011

// =============================================================================
// MA DIEU KHIEN ALU (ALU Control Signals - 4 bit)
// =============================================================================
`define ALU_ADD         4'b0000
`define ALU_SUB         4'b0001
`define ALU_SLL         4'b0010  // Shift Left Logical
`define ALU_SLT         4'b0011  // Set Less Than (Signed)
`define ALU_SLTU        4'b0100  // Set Less Than (Unsigned)
`define ALU_XOR         4'b0101
`define ALU_SRL         4'b0110  // Shift Right Logical
`define ALU_SRA         4'b0111  // Shift Right Arithmetic
`define ALU_OR          4'b1000
`define ALU_AND         4'b1001
`define ALU_COPY_B      4'b1010  // Tra ve toan hang B (dung cho LUI)

// =============================================================================
// MA CHON DINH DANG IMMEDIATE (ImmGen Select - 3 bit)
// =============================================================================
`define IMM_I           3'b000
`define IMM_S           3'b001
`define IMM_B           3'b010
`define IMM_U           3'b011
`define IMM_J           3'b100

// =============================================================================
// NGUON GHI VE THANH GHI DICH (WB Source Select - 2 bit)
// =============================================================================
`define WB_SRC_ALU      2'b00   // Ket qua tu ALU
`define WB_SRC_MEM      2'b01   // Du lieu doc tu bo nho
`define WB_SRC_PC_PLUS4 2'b10   // PC + 4 (dung cho JAL, JALR)
`define WB_SRC_CSR      2'b11   // Du lieu doc tu CSR

// =============================================================================
// MA FUNCT3 CHO DONG LENH BRANCH / LOAD / STORE / SYSTEM
// =============================================================================
// Branch Funct3
`define FUNCT3_BEQ      3'b000
`define FUNCT3_BNE      3'b001
`define FUNCT3_BLT      3'b100
`define FUNCT3_BGE      3'b101
`define FUNCT3_BLTU     3'b110
`define FUNCT3_BGEU     3'b111

// Load Funct3
`define FUNCT3_LB       3'b000
`define FUNCT3_LH       3'b001
`define FUNCT3_LW       3'b010
`define FUNCT3_LBU      3'b100
`define FUNCT3_LHU      3'b101

// Store Funct3
`define FUNCT3_SB       3'b000
`define FUNCT3_SH       3'b001
`define FUNCT3_SW       3'b010

// System / CSR Funct3
`define FUNCT3_CSRRW    3'b001
`define FUNCT3_CSRRS    3'b010
`define FUNCT3_CSRRC    3'b011
`define FUNCT3_CSRRWI   3'b101
`define FUNCT3_CSRRSI   3'b110
`define FUNCT3_CSRRCI   3'b111

// =============================================================================
// MA DINH NGHIA CHO RV32M EXTENSION (MULTIPLY & DIVIDE)
// =============================================================================
`define FUNCT7_M_EXT    7'b0000001

// RV32M Funct3
`define FUNCT3_MUL      3'b000  // Multiply Low 32-bit (Signed * Signed / Unsigned * Unsigned)
`define FUNCT3_MULH     3'b001  // Multiply High 32-bit (Signed * Signed)
`define FUNCT3_MULHSU   3'b010  // Multiply High 32-bit (Signed * Unsigned)
`define FUNCT3_MULHU    3'b011  // Multiply High 32-bit (Unsigned * Unsigned)
`define FUNCT3_DIV      3'b100  // Divide (Signed)
`define FUNCT3_DIVU     3'b101  // Divide (Unsigned)
`define FUNCT3_REM      3'b110  // Remainder (Signed)
`define FUNCT3_REMU     3'b111  // Remainder (Unsigned)

// Nguon chon ket qua EX stage (ALU vs Multiplier vs Divider)
`define EX_RES_ALU      2'b00
`define EX_RES_MUL      2'b01
`define EX_RES_DIV      2'b10

`endif // DEFINES_VH
