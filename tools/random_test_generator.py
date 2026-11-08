import random
import os
import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path(r"C:\Users\BuiThanhQui\CPU-pineline")

# Mask 32-bit
MASK32 = 0xFFFFFFFF

def to_signed(val):
    val = val & MASK32
    return val - 0x100000000 if val & 0x80000000 else val

def to_unsigned(val):
    return val & MASK32

class RV32IMGoldenModel:
    def __init__(self):
        self.regs = [0] * 32
        self.mem = {} # word address -> 32-bit word

    def step(self, op, rd, rs1, rs2, imm):
        v1 = self.regs[rs1]
        v2 = self.regs[rs2]
        res = 0

        # Arithmetic R-type
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
            shamt = v2 & 0x1F
            res = (v1 << shamt) & MASK32
        elif op == 'srl':
            shamt = v2 & 0x1F
            res = (v1 >> shamt) & MASK32
        elif op == 'sra':
            shamt = v2 & 0x1F
            s_v1 = to_signed(v1)
            res = (s_v1 >> shamt) & MASK32
        elif op == 'slt':
            res = 1 if to_signed(v1) < to_signed(v2) else 0
        elif op == 'sltu':
            res = 1 if to_unsigned(v1) < to_unsigned(v2) else 0

        # Immediate I-type
        elif op == 'addi':
            res = (v1 + imm) & MASK32
        elif op == 'andi':
            res = (v1 & (imm & MASK32)) & MASK32
        elif op == 'ori':
            res = (v1 | (imm & MASK32)) & MASK32
        elif op == 'xori':
            res = (v1 ^ (imm & MASK32)) & MASK32
        elif op == 'slli':
            shamt = imm & 0x1F
            res = (v1 << shamt) & MASK32
        elif op == 'srli':
            shamt = imm & 0x1F
            res = (v1 >> shamt) & MASK32
        elif op == 'srai':
            shamt = imm & 0x1F
            res = (to_signed(v1) >> shamt) & MASK32
        elif op == 'slti':
            res = 1 if to_signed(v1) < imm else 0
        elif op == 'sltiu':
            res = 1 if to_unsigned(v1) < to_unsigned(imm) else 0
        elif op == 'lui':
            res = (imm << 12) & MASK32

        # RV32M
        elif op == 'mul':
            res = (to_signed(v1) * to_signed(v2)) & MASK32
        elif op == 'mulh':
            p = to_signed(v1) * to_signed(v2)
            res = (p >> 32) & MASK32
        elif op == 'mulhu':
            p = to_unsigned(v1) * to_unsigned(v2)
            res = (p >> 32) & MASK32
        elif op == 'mulhsu':
            p = to_signed(v1) * to_unsigned(v2)
            res = (p >> 32) & MASK32
        elif op == 'div':
            s1 = to_signed(v1)
            s2 = to_signed(v2)
            if s2 == 0:
                res = MASK32 # -1
            elif s1 == -0x80000000 and s2 == -1:
                res = 0x80000000 # Overflow
            else:
                q = int(s1 / s2)
                res = q & MASK32
        elif op == 'divu':
            u1 = to_unsigned(v1)
            u2 = to_unsigned(v2)
            if u2 == 0:
                res = MASK32
            else:
                res = (u1 // u2) & MASK32
        elif op == 'rem':
            s1 = to_signed(v1)
            s2 = to_signed(v2)
            if s2 == 0:
                res = v1
            elif s1 == -0x80000000 and s2 == -1:
                res = 0
            else:
                r = abs(s1) % abs(s2)
                if s1 < 0:
                    r = -r
                res = r & MASK32
        elif op == 'remu':
            u1 = to_unsigned(v1)
            u2 = to_unsigned(v2)
            if u2 == 0:
                res = v1
            else:
                res = (u1 % u2) & MASK32

        if rd != 0:
            self.regs[rd] = res & MASK32
        self.regs[0] = 0

def generate_random_test(num_instructions=150, seed=42):
    random.seed(seed)
    model = RV32IMGoldenModel()
    asm_lines = []
    asm_lines.append("# CONSTAINED RANDOM TEST SUITE VS GOLDEN MODEL")
    asm_lines.append("_start:")

    # Initialize all registers with non-trivial values
    for r in range(1, 32):
        val = random.randint(-2048, 2047)
        asm_lines.append(f"    addi x{r}, x0, {val}")
        model.step('addi', r, 0, 0, val)

    r_ops = ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu',
             'mul', 'mulh', 'mulhu', 'mulhsu', 'div', 'divu', 'rem', 'remu']
    i_ops = ['addi', 'andi', 'ori', 'xori', 'slli', 'srli', 'srai', 'slti', 'sltiu']

    last_rd = 1

    for _ in range(num_instructions):
        # 50% chance to reuse last_rd as source to stress back-to-back RAW forwarding
        if random.random() < 0.5:
            rs1 = last_rd
        else:
            rs1 = random.randint(0, 31)

        rs2 = random.randint(0, 31)
        rd  = random.randint(0, 31) # includes x0 to verify suppression
        last_rd = rd if rd != 0 else 1

        category = random.choice(['R', 'I', 'LUI'])

        if category == 'R':
            op = random.choice(r_ops)
            asm_lines.append(f"    {op} x{rd}, x{rs1}, x{rs2}")
            model.step(op, rd, rs1, rs2, 0)
        elif category == 'I':
            op = random.choice(i_ops)
            if op in ['slli', 'srli', 'srai']:
                imm = random.randint(0, 31)
            else:
                imm = random.randint(-2048, 2047)
            asm_lines.append(f"    {op} x{rd}, x{rs1}, {imm}")
            model.step(op, rd, rs1, 0, imm)
        elif category == 'LUI':
            imm20 = random.randint(0, 0xFFFFF)
            asm_lines.append(f"    lui x{rd}, {hex(imm20)}")
            model.step('lui', rd, 0, 0, imm20)

    asm_lines.append("    ecall")
    return "\n".join(asm_lines), model.regs

if __name__ == "__main__":
    code, golden_regs = generate_random_test(num_instructions=350, seed=99999)
    out_s = REPO_ROOT / "coverage" / "random_test.s"
    out_hex = REPO_ROOT / "coverage" / "random_test.hex"
    with open(out_s, "w") as f:
        f.write(code)

    cmd = [sys.executable, str(REPO_ROOT / "tools" / "rv32im_assembler.py"), str(out_s), str(out_hex)]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(res.stdout)
    print("Golden Model final registers:")
    for i in range(32):
        print(f"x{i:<2} = 0x{golden_regs[i]:08X}", end="  " if (i+1)%4 != 0 else "\n")

    # Generate Verilog Scoreboard checks
    checks = []
    checks.append("// Golden Model Scoreboard Verification")
    for i in range(32):
        checks.append(f"        if (dut.cpu_inst.datapath_inst.reg_file.registers[{i}] === 32'h{golden_regs[i]:08x}) begin")
        checks.append(f"            $display(\"[PASS] [GOLDEN_CHECK] x{i:<2} = 0x%08X (Exp: 0x{golden_regs[i]:08x})\", dut.cpu_inst.datapath_inst.reg_file.registers[{i}]);")
        checks.append(f"            pass_count = pass_count + 1;")
        checks.append(f"        end else begin")
        checks.append(f"            $error(\"[FAIL] [GOLDEN_CHECK] x{i:<2} = 0x%08X (Exp: 0x{golden_regs[i]:08x})\", dut.cpu_inst.datapath_inst.reg_file.registers[{i}]);")
        checks.append(f"            fail_count = fail_count + 1;")
        checks.append(f"        end")

    with open(REPO_ROOT / "coverage" / "golden_checks.vh", "w") as f:
        f.write("\n".join(checks))
    print(f"\nWrote Verilog Scoreboard checks to {REPO_ROOT / 'coverage' / 'golden_checks.vh'}")
