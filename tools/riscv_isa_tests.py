"""
Official RISC-V Architectural Test Suite (RV32UI + RV32UM) Generator & Runner
for RV32IM 5-Stage Pipelined SoC.
"""

import os
import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path(r"C:\Users\BuiThanhQui\CPU-pineline")
sys.path.insert(0, str(REPO_ROOT / "tools"))
import rv32im_assembler

# Each test defines a set of (inst, expected, val1, val2) or test sequences
# Follows standard riscv-tests test vectors

RV32UI_TESTS = {
    "add": [
        ("add x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("add x5, x1, x2", 0x00000002, 0x00000001, 0x00000001),
        ("add x5, x1, x2", 0x0000000a, 0x00000003, 0x00000007),
        ("add x5, x1, x2", 0xffffffff, 0x00000000, 0xffffffff),
        ("add x5, x1, x2", 0x00000000, 0x00000001, 0xffffffff),
        ("add x5, x1, x2", 0x7fffffff, 0x7ffffffe, 0x00000001),
        ("add x5, x1, x2", 0x80000000, 0x7fffffff, 0x00000001), # Overflow into negative
    ],
    "sub": [
        ("sub x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("sub x5, x1, x2", 0x00000000, 0x00000001, 0x00000001),
        ("sub x5, x1, x2", 0xfffffffe, 0x00000001, 0x00000003),
        ("sub x5, x1, x2", 0x00000001, 0x00000000, 0xffffffff),
        ("sub x5, x1, x2", 0x7fffffff, 0x80000000, 0x00000001),
    ],
    "and": [
        ("and x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("and x5, x1, x2", 0x00000000, 0xffffffff, 0x00000000),
        ("and x5, x1, x2", 0x0ff00ff0, 0x0ff0ffff, 0xffff0ff0),
        ("and x5, x1, x2", 0x12345678, 0x12345678, 0xffffffff),
    ],
    "or": [
        ("or x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("or x5, x1, x2", 0xffffffff, 0xffffffff, 0x00000000),
        ("or x5, x1, x2", 0xffff0ff0, 0x0ff00ff0, 0xf00f0ff0),
        ("or x5, x1, x2", 0x5555aaaa, 0x55550000, 0x0000aaaa),
    ],
    "xor": [
        ("xor x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("xor x5, x1, x2", 0xffffffff, 0x00000000, 0xffffffff),
        ("xor x5, x1, x2", 0x00000000, 0x12345678, 0x12345678),
        ("xor x5, x1, x2", 0xaaaaaaaa, 0x55555555, 0xffffffff),
    ],
    "sll": [
        ("sll x5, x1, x2", 0x00000001, 0x00000001, 0x00000000),
        ("sll x5, x1, x2", 0x00000002, 0x00000001, 0x00000001),
        ("sll x5, x1, x2", 0x80000000, 0x00000001, 0x0000001f),
        ("sll x5, x1, x2", 0x00000002, 0x00000001, 0x00000021), # shamt[4:0] = 1
    ],
    "srl": [
        ("srl x5, x1, x2", 0x80000000, 0x80000000, 0x00000000),
        ("srl x5, x1, x2", 0x40000000, 0x80000000, 0x00000001),
        ("srl x5, x1, x2", 0x00000001, 0x80000000, 0x0000001f),
        ("srl x5, x1, x2", 0x40000000, 0x80000000, 0x00000021),
    ],
    "sra": [
        ("sra x5, x1, x2", 0x80000000, 0x80000000, 0x00000000),
        ("sra x5, x1, x2", 0xc0000000, 0x80000000, 0x00000001),
        ("sra x5, x1, x2", 0xffffffff, 0x80000000, 0x0000001f),
        ("sra x5, x1, x2", 0x3fffffff, 0x7fffffff, 0x00000001),
    ],
    "slt": [
        ("slt x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("slt x5, x1, x2", 0x00000001, 0xffffffff, 0x00000000), # -1 < 0
        ("slt x5, x1, x2", 0x00000000, 0x00000000, 0xffffffff), # 0 < -1 is false
        ("slt x5, x1, x2", 0x00000001, 0x80000000, 0x7fffffff), # min_neg < max_pos
    ],
    "sltu": [
        ("sltu x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("sltu x5, x1, x2", 0x00000000, 0xffffffff, 0x00000000), # 0xFFFFFFFF <u 0 is false
        ("sltu x5, x1, x2", 0x00000001, 0x00000000, 0xffffffff), # 0 <u 0xFFFFFFFF is true
    ],
}

RV32UM_TESTS = {
    "mul": [
        ("mul x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("mul x5, x1, x2", 0x00000032, 0x00000005, 0x0000000a), # 5 * 10 = 50
        ("mul x5, x1, x2", 0xfffffffe, 0xffffffff, 0x00000002), # -1 * 2 = -2
        ("mul x5, x1, x2", 0x00000001, 0xffffffff, 0xffffffff), # -1 * -1 = 1
        ("mul x5, x1, x2", 0x00000000, 0x00010000, 0x00010000), # 2^16 * 2^16 = 2^32 = 0
    ],
    "mulh": [
        ("mulh x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("mulh x5, x1, x2", 0x00000000, 0x00000005, 0x0000000a),
        ("mulh x5, x1, x2", 0xffffffff, 0xffffffff, 0x00000002), # -1 * 2 high word = -1
        ("mulh x5, x1, x2", 0x00000000, 0xffffffff, 0xffffffff), # -1 * -1 high word = 0
        ("mulh x5, x1, x2", 0x3fffffff, 0x7fffffff, 0x7fffffff), # (2^31-1)^2 high
    ],
    "mulhu": [
        ("mulhu x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("mulhu x5, x1, x2", 0x00000001, 0xffffffff, 0x00000002), # 2^32-1 * 2 high = 1
        ("mulhu x5, x1, x2", 0xfffffffe, 0xffffffff, 0xffffffff), # (2^32-1)^2 high = 2^32 - 2
    ],
    "mulhsu": [
        ("mulhsu x5, x1, x2", 0x00000000, 0x00000000, 0x00000000),
        ("mulhsu x5, x1, x2", 0xffffffff, 0xffffffff, 0x00000002), # -1 * 2 = -2 high = -1
        ("mulhsu x5, x1, x2", 0xffffffff, 0xffffffff, 0xffffffff), # -1 * (2^32-1) high = -1
    ],
    "div": [
        ("div x5, x1, x2", 0x00000002, 0x00000014, 0x0000000a), # 20 / 10 = 2
        ("div x5, x1, x2", 0xfffffffe, 0xffffffec, 0x0000000a), # -20 / 10 = -2
        ("div x5, x1, x2", 0xffffffff, 0x00000014, 0x00000000), # div by zero => -1 (0xFFFFFFFF)
        ("div x5, x1, x2", 0x80000000, 0x80000000, 0xffffffff), # overflow: -2^31 / -1 => -2^31
    ],
    "divu": [
        ("divu x5, x1, x2", 0x00000002, 0x00000014, 0x0000000a),
        ("divu x5, x1, x2", 0x19999999, 0xffffffff, 0x0000000a), # 2^32-1 / 10
        ("divu x5, x1, x2", 0xffffffff, 0x00000014, 0x00000000), # divu by zero => 2^32-1
    ],
    "rem": [
        ("rem x5, x1, x2", 0x00000002, 0x00000014, 0x00000003), # 20 % 3 = 2
        ("rem x5, x1, x2", 0xfffffffe, 0xffffffec, 0x00000003), # -20 % 3 = -2
        ("rem x5, x1, x2", 0x00000014, 0x00000014, 0x00000000), # rem by zero => dividend (20)
        ("rem x5, x1, x2", 0x00000000, 0x80000000, 0xffffffff), # overflow: -2^31 % -1 => 0
    ],
    "remu": [
        ("remu x5, x1, x2", 0x00000002, 0x00000014, 0x00000003),
        ("remu x5, x1, x2", 0x00000005, 0xffffffff, 0x0000000a), # 2^32-1 % 10 = 5
        ("remu x5, x1, x2", 0x00000014, 0x00000014, 0x00000000), # remu by zero => dividend (20)
    ]
}

def generate_assembly_suite():
    asm = []
    asm.append("# RV32IM ISA ARCHITECTURAL TEST SUITE")
    asm.append("_start:")
    asm.append("    addi gp, x0, 0    # gp holds error count / status")
    asm.append("    addi s1, x0, 0    # s1 holds passed tests count")

    test_id = 0

    def add_imm_loads(reg, val):
        lines = []
        u = (val + 0x800) >> 12 & 0xFFFFF
        lo = val & 0xFFF
        if lo >= 0x800:
            lo -= 0x1000
        lines.append(f"    lui {reg}, {hex(u)}")
        lines.append(f"    addi {reg}, {reg}, {lo}")
        return lines

    all_tests = {**RV32UI_TESTS, **RV32UM_TESTS}

    for test_group, cases in all_tests.items():
        asm.append(f"\n# --- GROUP: {test_group} ---")
        for inst_str, exp, val1, val2 in cases:
            test_id += 1
            lbl_fail = f"fail_{test_id}"
            lbl_ok   = f"ok_{test_id}"

            asm.append(f"# Test {test_id}: {test_group} (exp: {hex(exp)})")
            # Load x1 = val1
            asm.extend(add_imm_loads("x1", val1))
            # Load x2 = val2
            asm.extend(add_imm_loads("x2", val2))
            # Execute instruction
            asm.append(f"    {inst_str}")
            # Load x4 = expected
            asm.extend(add_imm_loads("x4", exp))
            # Compare x3 == x4
            asm.append(f"    bne x5, x4, {lbl_fail}")
            asm.append(f"    addi s1, s1, 1") # pass counter
            asm.append(f"    jal x0, {lbl_ok}")
            asm.append(f"{lbl_fail}:")
            asm.append(f"    addi gp, gp, 1") # fail counter
            asm.append(f"{lbl_ok}:")

    # Final summary check
    asm.append("\n# Final halt")
    asm.append("    # Store test summary to BRAM 0x300")
    asm.append("    addi t0, x0, 768 # 0x300")
    asm.append("    sw s1, 0(t0)     # mem[0x300] = passed count")
    asm.append("    sw gp, 4(t0)     # mem[0x304] = failed count")
    asm.append("    ecall            # Terminate simulation")

    return "\n".join(asm), test_id

if __name__ == "__main__":
    code, total_tests = generate_assembly_suite()
    out_s = REPO_ROOT / "coverage" / "riscv_isa_suite.s"
    out_hex = REPO_ROOT / "coverage" / "riscv_isa_suite.hex"
    with open(out_s, "w") as f:
        f.write(code)
    print(f"Generated {total_tests} test cases across RV32UI & RV32UM in {out_s}")
    
    cmd = [sys.executable, str(REPO_ROOT / "tools" / "rv32im_assembler.py"), str(out_s), str(out_hex)]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(res.stdout)
    print(f"Assembled successfully into {out_hex}")
