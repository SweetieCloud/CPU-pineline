import subprocess
import shutil
import sys
from pathlib import Path

REPO = Path(r"C:\Users\BuiThanhQui\CPU-pineline")
VIVADO = Path(r"C:\Xilinx\Vivado\2022.2\bin")
XVLOG = str(VIVADO / "xvlog.bat")
XELAB = str(VIVADO / "xelab.bat")
XSIM  = str(VIVADO / "xsim.bat")

sim_dir = REPO / "coverage" / "pipeline_stress_run"
sim_dir.mkdir(parents=True, exist_ok=True)

# Copy hex file to simulation directory
shutil.copy2(REPO / "coverage" / "soc_pipeline_stress.hex", sim_dir / "soc_pipeline_stress.hex")

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
    str(REPO / "vivado" / "vivado.srcs" / "sim_1" / "new" / "soc_pipeline_stress_tb.v")
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
cmd_elab = [XELAB, "soc_pipeline_stress_tb", "-s", "stress_snap", "-timescale", "1ns/1ps"]
r = subprocess.run(cmd_elab, cwd=sim_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
if r.returncode != 0:
    print("xelab failed:\n", r.stdout)
    sys.exit(1)
print("xelab PASSED.", flush=True)

print("3. Simulating snapshot with xsim -R...", flush=True)
cmd_sim = [XSIM, "stress_snap", "-R"]
r = subprocess.run(cmd_sim, cwd=sim_dir, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
print("xsim exit code:", r.returncode)
print(r.stdout)
