import random
import subprocess
import sys
from pathlib import Path
from golden_model_tracer import RV32IMGoldenTracer, MASK32, to_signed, to_unsigned

REPO = Path(r"C:\Users\BuiThanhQui\CPU-pineline")

def generate_multi_seed_suite(num_seeds=100, insts_per_seed=15):
    tracer = RV32IMGoldenTracer()
    asm_lines = []
    asm_lines.append("# =============================================================================")
    asm_lines.append("# MULTI-SEED INSTRUCTION-BY-INSTRUCTION RETIRE TRACE REGRESSION SUITE (100 SEEDS)")
    asm_lines.append("# =============================================================================")
    asm_lines.append("_start:")
    asm_lines.append("    # Initialize Base Pointer for Scratch Memory: lui s0, 3 (s0 = 0x3000 in BRAM)")
    asm_lines.append("    lui s0, 3")

    pc = 0x00000000
    # First instruction: lui s0, 3 -> 0x00003437
    tracer.step_inst(0, pc, 'lui', 8, 0, 0, 3)
    pc += 4

    r_ops = ['add', 'sub', 'and', 'or', 'xor', 'sll', 'srl', 'sra', 'slt', 'sltu',
             'mul', 'mulh', 'mulhu', 'mulhsu', 'div', 'divu', 'rem', 'remu']
    i_ops = ['addi', 'andi', 'ori', 'xori', 'slli', 'srli', 'srai', 'slti', 'sltiu']

    for seed_idx in range(1, num_seeds + 1):
        random.seed(seed_idx * 1337 + 7)
        asm_lines.append(f"\n# --- SEED {seed_idx} ---")

        # Initialize working registers x1..x7 for this seed
        for r in range(1, 8):
            init_val = random.randint(-1000, 1000)
            asm_lines.append(f"    addi x{r}, x0, {init_val}")
            tracer.step_inst(seed_idx, pc, 'addi', r, 0, 0, init_val)
            pc += 4

        last_rd = 1
        for _ in range(insts_per_seed):
            # 50% chance of RAW data hazard (reuse last_rd)
            rs1 = last_rd if random.random() < 0.5 else random.randint(1, 7)
            rs2 = random.randint(1, 7)
            rd  = random.randint(1, 7)
            last_rd = rd

            cat = random.choice(['R', 'I', 'LUI', 'STORE_LOAD'])

            if cat == 'R':
                op = random.choice(r_ops)
                # To prevent division by zero in random test:
                if op in ['div', 'divu', 'rem', 'remu']:
                    # ensure rs2 != 0
                    if tracer.regs[rs2] == 0:
                        asm_lines.append(f"    addi x{rs2}, x0, 7")
                        tracer.step_inst(seed_idx, pc, 'addi', rs2, 0, 0, 7)
                        pc += 4
                asm_lines.append(f"    {op} x{rd}, x{rs1}, x{rs2}")
                tracer.step_inst(seed_idx, pc, op, rd, rs1, rs2, 0)
                pc += 4

            elif cat == 'I':
                op = random.choice(i_ops)
                imm = random.randint(0, 31) if op in ['slli', 'srli', 'srai'] else random.randint(-1000, 1000)
                asm_lines.append(f"    {op} x{rd}, x{rs1}, {imm}")
                tracer.step_inst(seed_idx, pc, op, rd, rs1, 0, imm)
                pc += 4

            elif cat == 'LUI':
                imm20 = random.randint(1, 0x7FFFF)
                asm_lines.append(f"    lui x{rd}, {hex(imm20)}")
                tracer.step_inst(seed_idx, pc, 'lui', rd, 0, 0, imm20)
                pc += 4

            elif cat == 'STORE_LOAD':
                # Word store to scratch memory and load back
                offset = (random.randint(0, 15) * 4) # word-aligned offset 0..60
                asm_lines.append(f"    sw x{rs1}, {offset}(s0)")
                tracer.step_inst(seed_idx, pc, 'sw', 0, 8, rs1, offset)
                pc += 4

                asm_lines.append(f"    lw x{rd}, {offset}(s0)")
                tracer.step_inst(seed_idx, pc, 'lw', rd, 8, 0, offset)
                pc += 4

    asm_lines.append("\nfinish_multi_seed:")
    asm_lines.append("    ecall")
    asm_lines.append("    jal zero, finish_multi_seed")

    # Final ECALL in tracer
    tracer.step_inst(num_seeds, pc, 'ecall', 0, 0, 0, 0)

    # Write assembly file
    out_s = REPO / "coverage" / "multi_seed_trace.s"
    out_s.write_text("\n".join(asm_lines))

    # Write golden trace log
    out_log = REPO / "coverage" / "golden_retire_trace.log"
    with open(out_log, "w") as f:
        for rec in tracer.trace:
            f.write(str(rec) + "\n")

    print(f"Generated {len(asm_lines)} assembly lines across {num_seeds} seeds.")
    print(f"Generated {len(tracer.trace)} Golden Retire Records in {out_log}")

    # Assemble into HEX
    out_hex = REPO / "coverage" / "multi_seed_trace.hex"
    cmd = [sys.executable, str(REPO / "tools" / "rv32im_assembler.py"), str(out_s), str(out_hex)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("Assembler Error:", r.stderr)
        sys.exit(1)
    print(f"Assembled successfully into {out_hex}")

if __name__ == "__main__":
    generate_multi_seed_suite(num_seeds=100, insts_per_seed=15)
