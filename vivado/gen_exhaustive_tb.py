# Python assembler to build exhaustive test sequence

def enc_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_i(imm, rs1, funct3, rd, opcode):
    imm12 = imm & 0xFFF
    return (imm12 << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_s(imm, rs2, rs1, funct3, opcode):
    imm12 = imm & 0xFFF
    imm11_5 = (imm12 >> 5) & 0x7F
    imm4_0 = imm12 & 0x1F
    return (imm11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (imm4_0 << 7) | (opcode & 0x7F)

def enc_b(imm, rs2, rs1, funct3, opcode):
    imm13 = imm & 0x1FFF
    b12 = (imm13 >> 12) & 0x1
    b10_5 = (imm13 >> 5) & 0x3F
    b4_1 = (imm13 >> 1) & 0xF
    b11 = (imm13 >> 11) & 0x1
    return (b12 << 31) | (b10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | (b4_1 << 8) | (b11 << 7) | (opcode & 0x7F)

def enc_u(imm, rd, opcode):
    imm20 = (imm >> 12) & 0xFFFFF
    return (imm20 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def enc_j(imm, rd, opcode):
    imm21 = imm & 0x1FFFFF
    j20 = (imm21 >> 20) & 0x1
    j10_1 = (imm21 >> 1) & 0x3FF
    j11 = (imm21 >> 11) & 0x1
    j19_12 = (imm21 >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

OP_LUI    = 0x37
OP_AUIPC  = 0x17
OP_JAL    = 0x6F
OP_JALR   = 0x67
OP_BRANCH = 0x63
OP_LOAD   = 0x03
OP_STORE  = 0x23
OP_OP_IMM = 0x13
OP_OP     = 0x33
OP_SYSTEM = 0x73

class Asm:
    def __init__(self):
        self.items = [] # (type, args, comment)
        self.labels = {}

    def label(self, name):
        self.items.append(('label', name))

    def instr(self, gen_fn, comment):
        self.items.append(('instr', gen_fn, comment))

    def lui(self, rd, imm, c=""):
        self.instr(lambda pc, labels: enc_u(imm, rd, OP_LUI), f"lui x{rd}, {hex(imm)} # {c}")

    def auipc(self, rd, imm, c=""):
        self.instr(lambda pc, labels: enc_u(imm, rd, OP_AUIPC), f"auipc x{rd}, {hex(imm)} # {c}")

    def addi(self, rd, rs1, imm, c=""):
        self.instr(lambda pc, labels: enc_i(imm, rs1, 0x0, rd, OP_OP_IMM), f"addi x{rd}, x{rs1}, {imm} # {c}")

    def srai(self, rd, rs1, shamt, c=""):
        imm = 0x400 | (shamt & 0x1F)
        self.instr(lambda pc, labels: enc_i(imm, rs1, 0x5, rd, OP_OP_IMM), f"srai x{rd}, x{rs1}, {shamt} # {c}")

    def srli(self, rd, rs1, shamt, c=""):
        imm = shamt & 0x1F
        self.instr(lambda pc, labels: enc_i(imm, rs1, 0x5, rd, OP_OP_IMM), f"srli x{rd}, x{rs1}, {shamt} # {c}")

    def slt(self, rd, rs1, rs2, c=""):
        self.instr(lambda pc, labels: enc_r(0x00, rs2, rs1, 0x2, rd, OP_OP), f"slt x{rd}, x{rs1}, x{rs2} # {c}")

    def sltu(self, rd, rs1, rs2, c=""):
        self.instr(lambda pc, labels: enc_r(0x00, rs2, rs1, 0x3, rd, OP_OP), f"sltu x{rd}, x{rs1}, x{rs2} # {c}")

    def sub(self, rd, rs1, rs2, c=""):
        self.instr(lambda pc, labels: enc_r(0x20, rs2, rs1, 0x0, rd, OP_OP), f"sub x{rd}, x{rs1}, x{rs2} # {c}")

    def add_op(self, rd, rs1, rs2, c=""):
        self.instr(lambda pc, labels: enc_r(0x00, rs2, rs1, 0x0, rd, OP_OP), f"add x{rd}, x{rs1}, x{rs2} # {c}")

    def xori(self, rd, rs1, imm, c=""):
        self.instr(lambda pc, labels: enc_i(imm, rs1, 0x4, rd, OP_OP_IMM), f"xori x{rd}, x{rs1}, {imm} # {c}")

    def sb(self, rs2, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_s(offset, rs2, rs1, 0x0, OP_STORE), f"sb x{rs2}, {offset}(x{rs1}) # {c}")

    def sh(self, rs2, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_s(offset, rs2, rs1, 0x1, OP_STORE), f"sh x{rs2}, {offset}(x{rs1}) # {c}")

    def sw(self, rs2, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_s(offset, rs2, rs1, 0x2, OP_STORE), f"sw x{rs2}, {offset}(x{rs1}) # {c}")

    def lb(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x0, rd, OP_LOAD), f"lb x{rd}, {offset}(x{rs1}) # {c}")

    def lh(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x1, rd, OP_LOAD), f"lh x{rd}, {offset}(x{rs1}) # {c}")

    def lw(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x2, rd, OP_LOAD), f"lw x{rd}, {offset}(x{rs1}) # {c}")

    def lbu(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x4, rd, OP_LOAD), f"lbu x{rd}, {offset}(x{rs1}) # {c}")

    def lhu(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x5, rd, OP_LOAD), f"lhu x{rd}, {offset}(x{rs1}) # {c}")

    def beq(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x0, OP_BRANCH), f"beq x{rs1}, x{rs2}, {target_lbl} # {c}")

    def bne(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x1, OP_BRANCH), f"bne x{rs1}, x{rs2}, {target_lbl} # {c}")

    def blt(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x4, OP_BRANCH), f"blt x{rs1}, x{rs2}, {target_lbl} # {c}")

    def bge(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x5, OP_BRANCH), f"bge x{rs1}, x{rs2}, {target_lbl} # {c}")

    def bltu(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x6, OP_BRANCH), f"bltu x{rs1}, x{rs2}, {target_lbl} # {c}")

    def bgeu(self, rs1, rs2, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_b(labels[target_lbl] - pc, rs2, rs1, 0x7, OP_BRANCH), f"bgeu x{rs1}, x{rs2}, {target_lbl} # {c}")

    def jal(self, rd, target_lbl, c=""):
        self.instr(lambda pc, labels: enc_j(labels[target_lbl] - pc, rd, OP_JAL), f"jal x{rd}, {target_lbl} # {c}")

    def jalr(self, rd, rs1, offset, c=""):
        self.instr(lambda pc, labels: enc_i(offset, rs1, 0x0, rd, OP_JALR), f"jalr x{rd}, {offset}(x{rs1}) # {c}")

    def csrrw(self, rd, csr, rs1, c=""):
        self.instr(lambda pc, labels: enc_i(csr, rs1, 0x1, rd, OP_SYSTEM), f"csrrw x{rd}, {hex(csr)}, x{rs1} # {c}")

    def csrrs(self, rd, csr, rs1, c=""):
        self.instr(lambda pc, labels: enc_i(csr, rs1, 0x2, rd, OP_SYSTEM), f"csrrs x{rd}, {hex(csr)}, x{rs1} # {c}")

    def ecall(self, c=""):
        self.instr(lambda pc, labels: 0x00000073, f"ecall # {c}")

    def assemble(self):
        # Pass 1: find PC of each instruction and label
        pc = 0
        instr_list = []
        for item in self.items:
            if item[0] == 'label':
                self.labels[item[1]] = pc
            elif item[0] == 'instr':
                instr_list.append((pc, item[1], item[2]))
                pc += 4

        # Pass 2: generate machine code
        code = []
        for cur_pc, gen_fn, comment in instr_list:
            word = gen_fn(cur_pc, self.labels)
            code.append((cur_pc, word, comment))
        return code

a = Asm()

# --- PART 1: ARITHMETIC / SHIFTS / CORNER CASES ---
a.lui(8, 0x12345000, "x8 = 0x12345000")                       # idx 0
a.addi(9, 0, -1, "x9 = -1 (0xFFFFFFFF)")                     # idx 1
a.lui(10, 0x80000000, "x10 = 0x80000000")                   # idx 2
a.srai(11, 10, 3, "x11 = x10 >>> 3 = 0xF0000000")           # idx 3
a.srli(12, 10, 3, "x12 = x10 >> 3 = 0x10000000")            # idx 4
a.slt(13, 9, 0, "x13 = (x9 < 0) = 1")                        # idx 5
a.sltu(14, 9, 0, "x14 = (x9 <u 0) = 0")                      # idx 6
a.sub(15, 0, 9, "x15 = 0 - (-1) = 1")                        # idx 7
a.xori(16, 9, -1, "x16 = x9 ^ -1 = 0")                       # idx 8

# --- PART 2: SUB-WORD MEMORY (BYTE / HALFWORD EXTENSIONS) ---
a.addi(17, 0, 512, "x17 = 0x200 (Base dmem addr)")           # idx 9
a.addi(18, 0, 143, "x18 = 0x8F")                             # idx 10
a.sb(18, 17, 0, "mem[0x200][7:0] = 0x8F")                    # idx 11
a.lb(19, 17, 0, "x19 = sign_ext(0x8F) = 0xFFFFFF8F")         # idx 12
a.lbu(20, 17, 0, "x20 = zero_ext(0x8F) = 0x0000008F")        # idx 13
a.lui(21, 0x00008000, "x21 = 0x00008000")                    # idx 14
a.addi(21, 21, 5, "x21 = 0x00008005")                        # idx 15
a.sh(21, 17, 4, "mem[0x204][15:0] = 0x8005")                 # idx 16
a.lh(22, 17, 4, "x22 = sign_ext(0x8005) = 0xFFFF8005")       # idx 17
a.lhu(23, 17, 4, "x23 = zero_ext(0x8005) = 0x00008005")      # idx 18
a.lw(24, 17, 4, "x24 = word at 0x204 = 0x00008005")          # idx 19

# --- PART 3: ALL 6 BRANCH CONDITIONS & BACKWARD LOOP ---
# x9 is -1 (0xFFFFFFFF), x15 is 1 (0x00000001)
a.blt(9, 15, "lbl_blt_ok", "-1 < 1 signed is TRUE")          # idx 20
a.addi(1, 0, 1, "FAIL TRAP BLT")                             # idx 21
a.label("lbl_blt_ok")
a.bgeu(9, 15, "lbl_bgeu_ok", "0xFFFFFFFF >= 1 unsigned is TRUE") # idx 22
a.addi(2, 0, 1, "FAIL TRAP BGEU")                            # idx 23
a.label("lbl_bgeu_ok")
a.bltu(9, 15, "lbl_bltu_fail", "0xFFFFFFFF < 1 unsigned is FALSE") # idx 24
a.jal(0, "lbl_bltu_ok", "skip trap")                         # idx 25
a.label("lbl_bltu_fail")
a.addi(3, 0, 1, "FAIL TRAP BLTU")                            # idx 26
a.label("lbl_bltu_ok")
a.bge(9, 15, "lbl_bge_fail", "-1 >= 1 signed is FALSE")      # idx 27
a.jal(0, "lbl_bge_ok", "skip trap")                          # idx 28
a.label("lbl_bge_fail")
a.addi(4, 0, 1, "FAIL TRAP BGE")                             # idx 29
a.label("lbl_bge_ok")
a.beq(9, 15, "lbl_beq_fail", "-1 == 1 is FALSE")             # idx 30
a.jal(0, "lbl_beq_ok", "skip trap")                          # idx 31
a.label("lbl_beq_fail")
a.addi(7, 0, 1, "FAIL TRAP BEQ")                             # idx 32
a.label("lbl_beq_ok")
a.bne(9, 15, "lbl_bne_ok", "-1 != 1 is TRUE")                # idx 33
a.addi(1, 0, 2, "FAIL TRAP BNE")                             # idx 34
a.label("lbl_bne_ok")

# Backward loop (3 iterations)
a.addi(25, 0, 3, "x25 = 3 (loop counter)")                   # idx 35
a.label("lbl_loop")
a.addi(25, 25, -1, "x25 = x25 - 1")                          # idx 36
a.bne(25, 0, "lbl_loop", "loop until x25 == 0")              # idx 37

# --- PART 4: AUIPC & FUNCTION CALL/RETURN VIA JAL / JALR ---
a.jal(0, "lbl_skip_fn", "jump over function definition")      # idx 38
a.label("lbl_fn")
a.addi(28, 0, 77, "fn body: x28 = 77")                       # idx 39
a.jalr(0, 27, 0, "fn return to caller (0(x27))")              # idx 40
a.label("lbl_skip_fn")
a.auipc(26, 0, "x26 = PC of auipc")                          # idx 41
a.jal(27, "lbl_fn", "call fn, x27 = PC+4")                   # idx 42
a.label("lbl_after_call")

# --- PART 5: EXTREME PIPELINE HAZARDS ---
# Hazard 1: Write to x0 suppression
a.addi(0, 0, 99, "Write 99 to x0 (must be ignored)")         # idx 43
a.add_op(29, 0, 0, "x29 = x0 + x0 (must be 0)")              # idx 44

# Hazard 2: Back-to-back RAW forwarding cascade on same register
a.addi(30, 0, 10, "x30 = 10")                                # idx 45
a.addi(30, 30, 20, "x30 = 10 + 20 = 30")                     # idx 46
a.addi(30, 30, 30, "x30 = 30 + 30 = 60")                     # idx 47
a.addi(30, 30, 40, "x30 = 60 + 40 = 100")                    # idx 48

# Hazard 3: Load-Use Hazard directly into Branch
a.sw(30, 17, 8, "mem[0x208] = 100")                          # idx 49
a.lw(31, 17, 8, "x31 = mem[0x208] = 100")                    # idx 50
a.beq(31, 30, "lbl_load_use_ok", "stall & branch taken")     # idx 51
a.addi(1, 0, 99, "FAIL TRAP LOAD-USE BRANCH")                # idx 52
a.label("lbl_load_use_ok")

# --- PART 6: CSR OPERATIONS & TERMINATION ---
a.csrrw(5, 0x340, 30, "mscratch <= x30 (100), x5 <= old (0)") # idx 53
a.csrrs(6, 0x340, 0, "x6 <= mscratch (100), no modify")      # idx 54
a.ecall("halt simulation")                                   # idx 55

code = a.assemble()
print(f"Total instructions assembled: {len(code)}")
for i, (pc, word, comment) in enumerate(code):
    print(f"        mem[{i}] = 32'h{word:08x}; // 0x{pc:02x}: {comment}")
