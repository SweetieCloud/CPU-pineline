import subprocess
import shutil
import sys
import re
from pathlib import Path

REPO = Path(r"C:\Users\BuiThanhQui\CPU-pineline")
VIVADO = Path(r"C:\Xilinx\Vivado\2022.2\bin")
XVLOG = str(VIVADO / "xvlog.bat")
XELAB = str(VIVADO / "xelab.bat")
XSIM  = str(VIVADO / "xsim.bat")

sim_dir = REPO / "coverage" / "multi_seed_trace_run"
sim_dir.mkdir(parents=True, exist_ok=True)

# Copy hex file
shutil.copy2(REPO / "coverage" / "multi_seed_trace.hex", sim_dir / "multi_seed_trace.hex")

sources = [
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "alu.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "control_unit.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "register_file.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "forwarding_unit.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "hazard_unit.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "pipeline_registers.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "branch_comp.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "imm_gen.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "branch_predictor.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "multiplier.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "divider.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "csr_file.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "datapath.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "icache.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_lite_master_i.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_lite_master_d.v"),
    str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "cpu_top.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_interconnect.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_uart_lite.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_gpio.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_timer.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "soc_top.v"),
    str(REPO / "vivado" / "vivado.srcs" / "sim_1" / "new" / "soc_trace_tb.v")
]

print("1. Compiling sources with xvlog...", flush=True)
cmd_vlog = [XVLOG, "-sv", "-i", str(REPO / "vivado" / "vivado.srcs" / "sources_1" / "new"),
            "-i", str(REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new")] + sources
r = subprocess.run(cmd_vlog, cwd=sim_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
if r.returncode != 0:
    print("xvlog failed:\n", r.stdout)
    sys.exit(1)
print("xvlog PASSED.", flush=True)

print("2. Elaborating snapshot with xelab...", flush=True)
cmd_elab = [XELAB, "soc_trace_tb", "-s", "trace_snap", "-timescale", "1ns/1ps"]
r = subprocess.run(cmd_elab, cwd=sim_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
if r.returncode != 0:
    print("xelab failed:\n", r.stdout)
    sys.exit(1)
print("xelab PASSED.", flush=True)

print("3. Simulating 100-seed regression in xsim...", flush=True)
cmd_sim = [XSIM, "trace_snap", "-R"]
r = subprocess.run(cmd_sim, cwd=sim_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print("xsim exit code:", r.returncode)
print(r.stdout[-1500:])

# 4. Compare Traces Structurally
golden_log = REPO / "coverage" / "golden_retire_trace.log"
rtl_log    = sim_dir / "rtl_retire_trace.log"

if not rtl_log.exists():
    print(f"Error: {rtl_log} does not exist!")
    sys.exit(1)

def parse_record(line):
    # [RETIRE] PC=0x00000000 RD=x 8 VAL=0x00000600
    # or [RETIRE] SEED=... PC=0x... RD=x... VAL=0x...
    m = re.search(r'PC=0x([0-9a-fA-F]+)\s+RD=x\s*(\d+)\s+VAL=0x([0-9a-fA-F]+)', line)
    if not m:
        return None
    pc = int(m.group(1), 16)
    rd = int(m.group(2))
    val = int(m.group(3), 16)
    
    mem_m = re.search(r'MEM_WR ADDR=0x([0-9a-fA-F]+)\s+DATA=0x([0-9a-fA-F]+)', line)
    if mem_m:
        mem_we = True
        mem_addr = int(mem_m.group(1), 16)
        mem_data = int(mem_m.group(2), 16)
    else:
        mem_we = False
        mem_addr = 0
        mem_data = 0
    return (pc, rd, val, mem_we, mem_addr, mem_data)

with open(golden_log) as f:
    golden_lines = [l.strip() for l in f if l.strip()]

with open(rtl_log) as f:
    rtl_lines = [l.strip() for l in f if l.strip()]

golden_recs = [parse_record(l) for l in golden_lines]
rtl_recs    = [parse_record(l) for l in rtl_lines]

print("\n" + "=" * 80)
print("   INSTRUCTION-BY-INSTRUCTION RETIRE TRACE VERIFICATION RESULTS (100 SEEDS)")
print("=" * 80)
print(f"Golden Trace Total Records: {len(golden_recs)}")
print(f"RTL Trace Total Records   : {len(rtl_recs)}")

mismatches = 0
min_len = min(len(golden_recs), len(rtl_recs))

for i in range(min_len):
    g = golden_recs[i]
    r = rtl_recs[i]

    if g != r:
        if mismatches < 10:
            print(f"\n[MISMATCH] at record #{i+1}:")
            print(f"  Golden: PC=0x{g[0]:08X} RD=x{g[1]:<2} VAL=0x{g[2]:08X} MEM_WE={g[3]} ADDR=0x{g[4]:08X} DATA=0x{g[5]:08X}")
            print(f"  RTL   : PC=0x{r[0]:08X} RD=x{r[1]:<2} VAL=0x{r[2]:08X} MEM_WE={r[3]} ADDR=0x{r[4]:08X} DATA=0x{r[5]:08X}")
        mismatches += 1

if len(golden_recs) != len(rtl_recs):
    print(f"\n[LENGTH MISMATCH] Golden has {len(golden_recs)} records, RTL has {len(rtl_recs)} records!")
    mismatches += abs(len(golden_recs) - len(rtl_recs))

print("-" * 80)
if mismatches == 0:
    print(f"[SUCCESS] ALL {min_len} RETIRED INSTRUCTIONS MATCHED 100% PERFECTLY ACROSS ALL 100 SEEDS!")
    print("Zero glitches, zero transient forwarding errors, zero memory corruptions.")
    print("=" * 80 + "\n")
else:
    print(f"[FAILURE] Found {mismatches} instruction retirement mismatches!")
    print("=" * 80 + "\n")
    sys.exit(1)
