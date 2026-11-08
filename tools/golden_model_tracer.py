import random
import sys
from pathlib import Path

MASK32 = 0xFFFFFFFF

def to_signed(val):
    val = val & MASK32
    return val - 0x100000000 if val & 0x80000000 else val

def to_unsigned(val):
    return val & MASK32

class GoldenRetireRecord:
    def __init__(self, seed, pc, rd, rd_val, mem_we=False, mem_addr=0, mem_wdata=0, op='nop'):
        self.seed = seed
        self.pc = pc & MASK32
        self.rd = rd
        self.rd_val = rd_val & MASK32
        self.mem_we = mem_we
        self.mem_addr = mem_addr & MASK32
        self.mem_wdata = mem_wdata & MASK32
        self.op = op

    def __str__(self):
        s = f"[RETIRE] SEED={self.seed:<3} PC=0x{self.pc:08X} RD=x{self.rd:<2} VAL=0x{self.rd_val:08X}"
        if self.mem_we:
            s += f" MEM_WR ADDR=0x{self.mem_addr:08X} DATA=0x{self.mem_wdata:08X}"
        return s

class RV32IMGoldenTracer:
    def __init__(self):
        self.regs = [0] * 32
        self.mem = {} # byte address -> byte value
        self.csr = {
            0x340: 0 # mscratch
        }
        self.trace = []

    def read_mem(self, addr, size, signed=False):
        val = 0
        for i in range(size):
            b = self.mem.get((addr + i) & MASK32, 0)
            val |= (b << (8 * i))
        if signed:
            if size == 1 and (val & 0x80):
                val |= 0xFFFFFF00
            elif size == 2 and (val & 0x8000):
                val |= 0xFFFF0000
        return val & MASK32

    def write_mem(self, addr, size, val):
        for i in range(size):
            b = (val >> (8 * i)) & 0xFF
            self.mem[(addr + i) & MASK32] = b

    def step_inst(self, seed, pc, op, rd, rs1, rs2, imm):
        v1 = self.regs[rs1] if (0 <= rs1 < 32) else 0
        v2 = self.regs[rs2] if (0 <= rs2 < 32) else 0
        res = 0
        mem_we = False
        mem_addr = 0
        mem_wdata = 0
        next_pc = (pc + 4) & MASK32
        branch_taken = False

        # R-type ALU
        if op == 'add':
            res = (v1 + v2) & MASK32
        elif op == 'sub':
            res = (v1 - v2) & MASK32
        elif op == 'and':
            res = v1 & v2
        elif op == 'or':
            res = v1 | v2
        elif op == 'xor':
            res = v1 ^ v2
        elif op == 'sll':
            res = (v1 << (v2 & 0x1F)) & MASK32
        elif op == 'srl':
            res = (v1 >> (v2 & 0x1F)) & MASK32
        elif op == 'sra':
            res = (to_signed(v1) >> (v2 & 0x1F)) & MASK32
        elif op == 'slt':
            res = 1 if to_signed(v1) < to_signed(v2) else 0
        elif op == 'sltu':
            res = 1 if to_unsigned(v1) < to_unsigned(v2) else 0

        # I-type ALU
        elif op == 'addi':
            res = (v1 + imm) & MASK32
        elif op == 'andi':
            res = (v1 & (imm & MASK32)) & MASK32
        elif op == 'ori':
            res = (v1 | (imm & MASK32)) & MASK32
        elif op == 'xori':
            res = (v1 ^ (imm & MASK32)) & MASK32
        elif op == 'slli':
            res = (v1 << (imm & 0x1F)) & MASK32
        elif op == 'srli':
            res = (v1 >> (imm & 0x1F)) & MASK32
        elif op == 'srai':
            res = (to_signed(v1) >> (imm & 0x1F)) & MASK32
        elif op == 'slti':
            res = 1 if to_signed(v1) < imm else 0
        elif op == 'sltiu':
            res = 1 if to_unsigned(v1) < to_unsigned(imm) else 0

        # Upper Immediates
        elif op == 'lui':
            res = (imm << 12) & MASK32
        elif op == 'auipc':
            res = (pc + (imm << 12)) & MASK32

        # Jumps
        elif op == 'jal':
            res = (pc + 4) & MASK32
            next_pc = (pc + imm) & MASK32
            branch_taken = True
        elif op == 'jalr':
            res = (pc + 4) & MASK32
            next_pc = ((v1 + imm) & ~1) & MASK32
            branch_taken = True

        # Conditional Branches
        elif op == 'beq':
            branch_taken = (v1 == v2)
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32
        elif op == 'bne':
            branch_taken = (v1 != v2)
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32
        elif op == 'blt':
            branch_taken = (to_signed(v1) < to_signed(v2))
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32
        elif op == 'bge':
            branch_taken = (to_signed(v1) >= to_signed(v2))
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32
        elif op == 'bltu':
            branch_taken = (to_unsigned(v1) < to_unsigned(v2))
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32
        elif op == 'bgeu':
            branch_taken = (to_unsigned(v1) >= to_unsigned(v2))
            next_pc = (pc + imm) & MASK32 if branch_taken else (pc + 4) & MASK32

        # RV32M
        elif op == 'mul':
            res = (to_signed(v1) * to_signed(v2)) & MASK32
        elif op == 'mulh':
            res = ((to_signed(v1) * to_signed(v2)) >> 32) & MASK32
        elif op == 'mulhu':
            res = ((to_unsigned(v1) * to_unsigned(v2)) >> 32) & MASK32
        elif op == 'mulhsu':
            res = ((to_signed(v1) * to_unsigned(v2)) >> 32) & MASK32
        elif op == 'div':
            s1, s2 = to_signed(v1), to_signed(v2)
            if s2 == 0:
                res = MASK32
            elif s1 == -0x80000000 and s2 == -1:
                res = 0x80000000
            else:
                res = int(s1 / s2) & MASK32
        elif op == 'divu':
            u1, u2 = to_unsigned(v1), to_unsigned(v2)
            res = MASK32 if u2 == 0 else (u1 // u2) & MASK32
        elif op == 'rem':
            s1, s2 = to_signed(v1), to_signed(v2)
            if s2 == 0:
                res = v1
            elif s1 == -0x80000000 and s2 == -1:
                res = 0
            else:
                r = abs(s1) % abs(s2)
                if s1 < 0: r = -r
                res = r & MASK32
        elif op == 'remu':
            u1, u2 = to_unsigned(v1), to_unsigned(v2)
            res = v1 if u2 == 0 else (u1 % u2) & MASK32

        # Loads
        elif op == 'lw':
            addr = (v1 + imm) & MASK32
            res = self.read_mem(addr, 4, signed=True)
        elif op == 'lh':
            addr = (v1 + imm) & MASK32
            res = self.read_mem(addr, 2, signed=True)
        elif op == 'lhu':
            addr = (v1 + imm) & MASK32
            res = self.read_mem(addr, 2, signed=False)
        elif op == 'lb':
            addr = (v1 + imm) & MASK32
            res = self.read_mem(addr, 1, signed=True)
        elif op == 'lbu':
            addr = (v1 + imm) & MASK32
            res = self.read_mem(addr, 1, signed=False)

        # Stores
        elif op == 'sw':
            addr = (v1 + imm) & MASK32
            self.write_mem(addr, 4, v2)
            mem_we = True
            mem_addr = addr
            mem_wdata = v2
        elif op == 'sh':
            addr = (v1 + imm) & MASK32
            self.write_mem(addr, 2, v2 & 0xFFFF)
            mem_we = True
            mem_addr = addr
            mem_wdata = v2 & 0xFFFF
        elif op == 'sb':
            addr = (v1 + imm) & MASK32
            self.write_mem(addr, 1, v2 & 0xFF)
            mem_we = True
            mem_addr = addr
            mem_wdata = v2 & 0xFF

        # CSR
        elif op == 'csrrw':
            csr_addr = imm & 0xFFF
            old_val = self.csr.get(csr_addr, 0)
            self.csr[csr_addr] = v1 & MASK32
            res = old_val

        # Update Register File (for instructions that write rd)
        branch_ops = ['beq', 'bne', 'blt', 'bge', 'bltu', 'bgeu', 'sw', 'sh', 'sb', 'ecall']
        if rd != 0 and op not in branch_ops:
            self.regs[rd] = res & MASK32
        self.regs[0] = 0

        actual_rd_val = self.regs[rd] if rd != 0 else 0
        rec = GoldenRetireRecord(seed, pc, rd, actual_rd_val, mem_we, mem_addr, mem_wdata, op)
        self.trace.append(rec)
        return rec, next_pc, branch_taken
