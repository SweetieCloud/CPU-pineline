import os
import sys
import subprocess
from pathlib import Path

REPO_ROOT = Path(r"C:\Users\BuiThanhQui\CPU-pineline")
sys.path.insert(0, str(REPO_ROOT / "tools"))
import riscv_isa_tests
import rv32im_assembler

# Let's test each group individually to identify exactly which group fails!
all_groups = {**riscv_isa_tests.RV32UI_TESTS, **riscv_isa_tests.RV32UM_TESTS}

def test_single_group(group_name, cases):
    asm = []
    asm.append(f"_start:")
    asm.append("    addi gp, x0, 0")
    asm.append("    addi s1, x0, 0")
    
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

    for inst_str, exp, val1, val2 in cases:
        test_id += 1
        lbl_fail = f"fail_{test_id}"
        lbl_ok   = f"ok_{test_id}"
        asm.extend(add_imm_loads("x1", val1))
        asm.extend(add_imm_loads("x2", val2))
        asm.append(f"    {inst_str}")
        asm.extend(add_imm_loads("x4", exp))
        asm.append(f"    bne x5, x4, {lbl_fail}")
        asm.append(f"    addi s1, s1, 1")
        asm.append(f"    jal x0, {lbl_ok}")
        asm.append(f"{lbl_fail}:")
        asm.append(f"    addi gp, gp, 1")
        # Save failing info in x10, x11, x12
        asm.append(f"    addi x10, x0, {test_id}")
        asm.append(f"    addi x11, x5, 0 # got")
        asm.append(f"    addi x12, x4, 0 # expected")
        asm.append(f"{lbl_ok}:")

    asm.append("    ecall")
    return "\n".join(asm), len(cases)

def main():
    cov_dir = REPO_ROOT / "coverage"
    env = os.environ.copy()
    env["XILINX_VIVADO"] = r"C:\Xilinx\Vivado\2022.2"

    for grp, cases in all_groups.items():
        code, count = test_single_group(grp, cases)
        s_file = cov_dir / f"test_{grp}.s"
        hex_file = cov_dir / "riscv_isa_suite.hex"
        with open(s_file, "w") as f:
            f.write(code)
        
        # Assemble
        cmd = [sys.executable, str(REPO_ROOT / "tools" / "rv32im_assembler.py"), str(s_file), str(hex_file)]
        subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        # Run xsim
        xsim_cmd = [str(Path(r"C:\Xilinx\Vivado\2022.2\bin\xsim.bat")), "isa_sim", "-R"]
        res = subprocess.run(xsim_cmd, cwd=cov_dir, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

        # Extract s1 and gp from output
        # Look for Total Passed Tests (s1): X / Y
        passed = 0
        failed = 0
        for line in res.stdout.splitlines():
            if "Total Passed Tests" in line:
                passed = int(line.split(":")[-1].split("/")[0].strip())
            if "Total Failed Tests" in line:
                failed = int(line.split(":")[-1].strip())
        
        status = "PASS" if failed == 0 and passed == count else "FAIL"
        print(f"[{status}] Group {grp:<10}: Passed {passed}/{count}, Failed {failed}")

if __name__ == "__main__":
    main()
