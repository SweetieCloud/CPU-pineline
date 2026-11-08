import os
import sys
import subprocess
import shutil
import re
from pathlib import Path

REPO_ROOT = Path(r"C:\Users\BuiThanhQui\CPU-pineline")
VIVADO_BIN = Path(r"C:\Xilinx\Vivado\2022.2\bin")
COV_ROOT = REPO_ROOT / "coverage"

XVLOG = str(VIVADO_BIN / "xvlog.bat")
XELAB = str(VIVADO_BIN / "xelab.bat")
XSIM  = str(VIVADO_BIN / "xsim.bat")
XCRG  = str(VIVADO_BIN / "xcrg.bat")

INC_DIRS = [
    f"-i", str(REPO_ROOT / "vivado" / "vivado.srcs" / "sources_1" / "new"),
    f"-i", str(REPO_ROOT / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new")
]

SRC_DIR_VIVADO = REPO_ROOT / "vivado" / "vivado.srcs" / "sources_1" / "new"
SRC_DIR_CPU    = REPO_ROOT / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new"
SIM_DIR_VIVADO = REPO_ROOT / "vivado" / "vivado.srcs" / "sim_1" / "new"
SIM_DIR_CPU    = REPO_ROOT / "cpu_pipeline.srcs" / "sim_1" / "new"
SIM_IMP_CPU    = REPO_ROOT / "cpu_pipeline.srcs" / "sim_1" / "imports" / "new"

CPU_CORE_SOURCES = [
    str(SRC_DIR_CPU / "alu.v"),
    str(SRC_DIR_CPU / "control_unit.v"),
    str(SRC_DIR_CPU / "register_file.v"),
    str(SRC_DIR_CPU / "forwarding_unit.v"),
    str(SRC_DIR_CPU / "hazard_unit.v"),
    str(SRC_DIR_CPU / "pipeline_registers.v"),
    str(SRC_DIR_VIVADO / "branch_comp.v"),
    str(SRC_DIR_VIVADO / "imm_gen.v"),
    str(SRC_DIR_VIVADO / "branch_predictor.v"),
    str(SRC_DIR_VIVADO / "multiplier.v"),
    str(SRC_DIR_VIVADO / "divider.v"),
    str(SRC_DIR_VIVADO / "csr_file.v"),
    str(SRC_DIR_CPU / "datapath.v"),
    str(SRC_DIR_VIVADO / "icache.v"),
    str(SRC_DIR_VIVADO / "axi_lite_master_i.v"),
    str(SRC_DIR_VIVADO / "axi_lite_master_d.v"),
    str(SRC_DIR_CPU / "cpu_top.v"),
]

SOC_EXTRA_SOURCES = [
    str(SRC_DIR_VIVADO / "axi_interconnect.v"),
    str(SRC_DIR_VIVADO / "axi_uart_lite.v"),
    str(SRC_DIR_VIVADO / "axi_gpio.v"),
    str(SRC_DIR_VIVADO / "axi_timer.v"),
    str(SRC_DIR_VIVADO / "soc_top.v"),
]

TESTBENCHES = [
    {
        "name": "alu_tb",
        "top": "alu_tb",
        "sources": [str(SRC_DIR_CPU / "alu.v"), str(SIM_DIR_CPU / "alu_tb.v")],
        "dut_file": "alu.v"
    },
    {
        "name": "forwarding_tb",
        "top": "forwarding_tb",
        "sources": [str(SRC_DIR_CPU / "forwarding_unit.v"), str(SIM_DIR_CPU / "forwarding_tb.v")],
        "dut_file": "forwarding_unit.v"
    },
    {
        "name": "control_unit_tb",
        "top": "control_unit_tb",
        "sources": [str(SRC_DIR_CPU / "control_unit.v"), str(SIM_DIR_CPU / "control_unit_tb.v")],
        "dut_file": "control_unit.v"
    },
    {
        "name": "csr_file_tb",
        "top": "csr_file_tb",
        "sources": [str(SRC_DIR_VIVADO / "csr_file.v"), str(SIM_DIR_VIVADO / "csr_file_tb.v")],
        "dut_file": "csr_file.v"
    },
    {
        "name": "regfile_tb",
        "top": "regfile_tb",
        "sources": [str(SRC_DIR_CPU / "register_file.v"), str(SIM_DIR_CPU / "regfile_tb.v")],
        "dut_file": "register_file.v"
    },
    {
        "name": "branch_predictor_tb",
        "top": "branch_predictor_tb",
        "sources": [str(SRC_DIR_VIVADO / "branch_predictor.v"), str(SIM_DIR_VIVADO / "branch_predictor_tb.v")],
        "dut_file": "branch_predictor.v"
    },
    {
        "name": "multiplier_tb",
        "top": "multiplier_tb",
        "sources": [str(SRC_DIR_VIVADO / "multiplier.v"), str(SIM_DIR_VIVADO / "multiplier_tb.v")],
        "dut_file": "multiplier.v"
    },
    {
        "name": "divider_tb",
        "top": "divider_tb",
        "sources": [str(SRC_DIR_VIVADO / "divider.v"), str(SIM_DIR_VIVADO / "divider_tb.v")],
        "dut_file": "divider.v"
    },
    {
        "name": "icache_tb",
        "top": "icache_tb",
        "sources": [str(SRC_DIR_VIVADO / "icache.v"), str(SIM_DIR_VIVADO / "icache_tb.v")],
        "dut_file": "icache.v"
    },
    {
        "name": "axi_gpio_tb",
        "top": "axi_gpio_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_gpio.v"), str(SIM_DIR_VIVADO / "axi_gpio_tb.v")],
        "dut_file": "axi_gpio.v"
    },
    {
        "name": "axi_timer_tb",
        "top": "axi_timer_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_timer.v"), str(SIM_DIR_VIVADO / "axi_timer_tb.v")],
        "dut_file": "axi_timer.v"
    },
    {
        "name": "axi_uart_lite_tb",
        "top": "axi_uart_lite_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_uart_lite.v"), str(SIM_DIR_VIVADO / "axi_uart_lite_tb.v")],
        "dut_file": "axi_uart_lite.v"
    },
    {
        "name": "axi_interconnect_tb",
        "top": "axi_interconnect_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_interconnect.v"), str(SIM_DIR_VIVADO / "axi_interconnect_tb.v")],
        "dut_file": "axi_interconnect.v"
    },
    {
        "name": "cpu_tb",
        "top": "cpu_tb",
        "sources": CPU_CORE_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_IMP_CPU / "cpu_tb.v")],
        "dut_file": "cpu_top.v"
    },
    {
        "name": "soc_tb",
        "top": "soc_tb",
        "sources": CPU_CORE_SOURCES + SOC_EXTRA_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_DIR_VIVADO / "soc_tb.v")],
        "dut_file": "soc_top.v"
    },
    {
        "name": "axi_stress_tb",
        "top": "axi_stress_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_interconnect.v"), str(SIM_DIR_VIVADO / "axi_stress_tb.v")],
        "dut_file": "axi_interconnect.v"
    },
    {
        "name": "uart_divisor434_tb",
        "top": "uart_divisor434_tb",
        "sources": [str(SRC_DIR_VIVADO / "axi_uart_lite.v"), str(SIM_DIR_VIVADO / "uart_divisor434_tb.v")],
        "dut_file": "axi_uart_lite.v"
    },
    {
        "name": "soc_isa_tb",
        "top": "soc_isa_tb",
        "sources": CPU_CORE_SOURCES + SOC_EXTRA_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_DIR_VIVADO / "soc_isa_tb.v")],
        "dut_file": "soc_top.v",
        "hex_files": [("riscv_isa_suite.hex", "riscv_isa_suite.hex")]
    },
    {
        "name": "soc_random_tb",
        "top": "soc_random_tb",
        "sources": CPU_CORE_SOURCES + SOC_EXTRA_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_DIR_VIVADO / "soc_random_tb.v")],
        "dut_file": "soc_top.v",
        "hex_files": [("random_test.hex", "random_test.hex"), ("golden_checks.vh", "golden_checks.vh")]
    },
    {
        "name": "soc_interrupt_tb",
        "top": "soc_interrupt_tb",
        "sources": CPU_CORE_SOURCES + SOC_EXTRA_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_DIR_VIVADO / "soc_interrupt_tb.v")],
        "dut_file": "soc_top.v",
        "hex_files": [("test_interrupt.hex", "test_interrupt.hex")]
    },
    {
        "name": "soc_firmware_tb",
        "top": "soc_firmware_tb",
        "sources": CPU_CORE_SOURCES + SOC_EXTRA_SOURCES + [str(SIM_DIR_VIVADO / "rv32i_sva.sv"), str(SIM_DIR_VIVADO / "soc_firmware_tb.v")],
        "dut_file": "soc_top.v"
    }
]

def run_cmd(cmd, cwd=None, env=None, timeout=180):
    try:
        res = subprocess.run(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
        return res.returncode, res.stdout
    except subprocess.TimeoutExpired:
        return -1, f"[TIMEOUT] Command exceeded {timeout} seconds limit"

def parse_html_table(files_html_path):
    if not os.path.exists(files_html_path):
        return {}
    with open(files_html_path, "r", encoding="utf-8", errors="ignore") as f:
        html = f.read()

    # Find rows in fileInfosTable
    # Pattern to match table rows
    rows = re.findall(r"<tr>(.*?)</tr>", html, re.DOTALL)
    file_stats = {}
    for r in rows:
        cells = re.findall(r"<td[^>]*>(.*?)</td>", r, re.DOTALL)
        if len(cells) >= 10:
            # File ID, File Path, Modules Count, Instances Count, Stmt %, Lines, Stmt, Branch %, Cond %, Toggle %
            path_match = re.search(r"<a[^>]*>(.*?)</a>", cells[1])
            filepath = path_match.group(1).strip() if path_match else cells[1].strip()
            filename = os.path.basename(filepath)
            def clean_val(v):
                v_clean = re.sub(r"<[^>]+>", "", v).strip()
                try:
                    return float(v_clean)
                except:
                    return v_clean
            file_stats[filename] = {
                "filepath": filepath,
                "stmt_score": clean_val(cells[4]),
                "lines": clean_val(cells[5]),
                "stmts": clean_val(cells[6]),
                "branch_score": clean_val(cells[7]),
                "cond_score": clean_val(cells[8]),
                "toggle_score": clean_val(cells[9]),
            }
    return file_stats

def main():
    env = os.environ.copy()
    env["XILINX_VIVADO"] = r"C:\Xilinx\Vivado\2022.2"

    COV_ROOT.mkdir(parents=True, exist_ok=True)
    hex_src = REPO_ROOT / "vivado" / "program.hex"
    if hex_src.exists():
        shutil.copy(hex_src, COV_ROOT / "program.hex")

    results = []

    force = "--force" in sys.argv
    print(f"=== STARTING AUTOMATED CODE COVERAGE MEASUREMENT ACROSS {len(TESTBENCHES)} TESTBENCHES ===", flush=True)

    for tb in TESTBENCHES:
        tb_name = tb["name"]
        tb_dir = COV_ROOT / tb_name
        tb_dir.mkdir(parents=True, exist_ok=True)
        report_dir = tb_dir / "cov_report"
        files_html = report_dir / "files.html"

        if files_html.exists() and files_html.stat().st_size > 500 and not force:
            print(f"---> [{tb_name}] Found existing verified coverage report. Skipping re-simulation.", flush=True)
            stats = parse_html_table(files_html)
            dut_stats = stats.get(tb["dut_file"], {})
            print(f"[{tb_name}] DUT: {tb['dut_file']} => Statement: {dut_stats.get('stmt_score')}% | Branch: {dut_stats.get('branch_score')}% | Condition: {dut_stats.get('cond_score')}% | Toggle: {dut_stats.get('toggle_score')}%", flush=True)
            results.append({
                "testbench": tb_name,
                "dut": tb["dut_file"],
                "all_stats": stats,
                "dut_stats": dut_stats
            })
            continue

        print(f"\n---> Running Coverage for [{tb_name}] (Top: {tb['top']})...", flush=True)
        if hex_src.exists():
            shutil.copy(hex_src, tb_dir / "program.hex")
        if "hex_files" in tb:
            for src_name, dst_name in tb["hex_files"]:
                src_path = COV_ROOT / src_name
                if src_path.exists():
                    shutil.copy(src_path, tb_dir / dst_name)

        tb_inc_dirs = INC_DIRS + ["-i", str(tb_dir)]

        # 1. XVLOG
        vlog_cmd = [XVLOG, "--sv"] + tb_inc_dirs + tb["sources"]
        ret, out = run_cmd(vlog_cmd, cwd=tb_dir, env=env)
        if ret != 0:
            print(f"[ERROR] xvlog failed for {tb_name}:\n{out[:500]}", flush=True)
            continue

        # 2. XELAB with coverage
        cov_db_name = f"{tb_name}_cov"
        elab_cmd = [XELAB, tb["top"], "-s", f"{tb_name}_sim", "-cc_type", "sbct", "-cov_db_dir", "./cov", "-cov_db_name", cov_db_name, "-timescale", "1ns/1ps", "--relax"] + tb_inc_dirs
        ret, out = run_cmd(elab_cmd, cwd=tb_dir, env=env)
        if ret != 0:
            print(f"[ERROR] xelab failed for {tb_name}:\n{out[:500]}", flush=True)
            continue

        # 3. XSIM
        run_tcl = tb_dir / "run.tcl"
        with open(run_tcl, "w") as f:
            f.write(f"run -all\nwrite_xsim_coverage -cov_db_dir ./cov -cov_db_name {cov_db_name}\nexit\n")

        xsim_cmd = [XSIM, f"{tb_name}_sim", "-t", "run.tcl"]
        ret, out = run_cmd(xsim_cmd, cwd=tb_dir, env=env)
        if ret != 0:
            print(f"[WARNING] xsim had nonzero exit for {tb_name}", flush=True)

        # 4. XCRG
        xcrg_cmd = [XCRG, "-cc_db", cov_db_name, "-cc_dir", "./cov/xsim.codeCov/", "-cc_report", str(report_dir), "-report_format", "html"]
        ret, out = run_cmd(xcrg_cmd, cwd=tb_dir, env=env)

        # Parse results
        stats = parse_html_table(files_html)
        dut_stats = stats.get(tb["dut_file"], {})

        print(f"[{tb_name}] DUT: {tb['dut_file']} => Statement: {dut_stats.get('stmt_score')}% | Branch: {dut_stats.get('branch_score')}% | Condition: {dut_stats.get('cond_score')}% | Toggle: {dut_stats.get('toggle_score')}%", flush=True)
        results.append({
            "testbench": tb_name,
            "dut": tb["dut_file"],
            "all_stats": stats,
            "dut_stats": dut_stats
        })

    # Summary table
    print("\n" + "="*85)
    print(f"{'Testbench':<22} | {'DUT File':<20} | {'Stmt(Line)%':<11} | {'Branch%':<8} | {'Cond%':<8} | {'Toggle%':<8}")
    print("="*85)
    for r in results:
        ds = r["dut_stats"]
        stmt = f"{ds.get('stmt_score', 0):.2f}" if isinstance(ds.get('stmt_score'), (int, float)) else str(ds.get('stmt_score', 'N/A'))
        br   = f"{ds.get('branch_score', 0):.2f}" if isinstance(ds.get('branch_score'), (int, float)) else str(ds.get('branch_score', 'N/A'))
        cond = f"{ds.get('cond_score', 0):.2f}" if isinstance(ds.get('cond_score'), (int, float)) else str(ds.get('cond_score', 'N/A'))
        togg = f"{ds.get('toggle_score', 0):.2f}" if isinstance(ds.get('toggle_score'), (int, float)) else str(ds.get('toggle_score', 'N/A'))
        print(f"{r['testbench']:<22} | {r['dut']:<20} | {stmt:<11} | {br:<8} | {cond:<8} | {togg:<8}")
    print("="*85)

    # Cross-testbench RTL Module Summary
    import json
    all_reports = list(COV_ROOT.glob("*/cov_report/files.html"))
    module_stats = {}
    for rep in all_reports:
        tb = rep.parent.parent.name
        parsed = parse_html_table(rep)
        for fn, f_data in parsed.items():
            if not fn.endswith(".v") and not fn.endswith(".sv"):
                continue
            if fn.endswith("_tb.v") or fn == "rv32i_sva.sv" or fn == "File Path":
                continue
            def num_or_zero(x):
                try: return float(x)
                except: return 0.0
            st = {
                "tb": tb,
                "stmt": num_or_zero(f_data.get("stmt_score", 0)),
                "branch": num_or_zero(f_data.get("branch_score", 0)),
                "cond": num_or_zero(f_data.get("cond_score", 0)),
                "toggle": num_or_zero(f_data.get("toggle_score", 0)),
                "lines": num_or_zero(f_data.get("lines", 0)),
                "stmts": num_or_zero(f_data.get("stmts", 0))
            }
            if fn not in module_stats:
                module_stats[fn] = []
            module_stats[fn].append(st)

    summary_table = []
    print("\n" + "="*95)
    print("   UNIFIED RTL MODULE CODE COVERAGE SUMMARY (ACROSS COMPREHENSIVE SUITE)")
    print("="*95)
    print(f"{'Module File':<24} | {'Best Testbench':<22} | {'Stmt%':<7} | {'Branch%':<7} | {'Cond%':<7} | {'Toggle%':<7}")
    print("-"*95)
    for fn in sorted(module_stats.keys()):
        entries = module_stats[fn]
        best = max(entries, key=lambda x: (x["stmt"], x["branch"], x["toggle"]))
        summary_table.append({
            "module": fn,
            "best_tb": best["tb"],
            "stmt": best["stmt"],
            "branch": best["branch"],
            "cond": best["cond"],
            "toggle": best["toggle"]
        })
        print(f"{fn:<24} | {best['tb']:<22} | {best['stmt']:>6.2f}% | {best['branch']:>6.2f}% | {best['cond']:>6.2f}% | {best['toggle']:>6.2f}%")
    print("="*95)

    # Save to JSON and Markdown
    summary_md_path = COV_ROOT / "coverage_summary.md"
    summary_json_path = COV_ROOT / "coverage_summary.json"
    with open(summary_json_path, "w", encoding="utf-8") as f:
        json.dump({"testbenches": results, "modules": summary_table}, f, indent=2)

    with open(summary_md_path, "w", encoding="utf-8") as f:
        f.write("# Vivado xSim / xcrg Code Coverage Verification Report\n\n")
        f.write("Generated using `xsim -cc_type sbct` (Statement, Branch, Condition, Toggle) and `xcrg`.\n\n")
        f.write("## 1. Testbench DUT Specific Coverage\n\n")
        f.write("| Testbench | DUT File | Statement (Line) % | Branch % | Condition % | Toggle % |\n")
        f.write("| :--- | :--- | :---: | :---: | :---: | :---: |\n")
        for r in results:
            ds = r["dut_stats"]
            f.write(f"| `{r['testbench']}` | `{r['dut']}` | {ds.get('stmt_score', 0):.2f}% | {ds.get('branch_score', 0):.2f}% | {ds.get('cond_score', 0):.2f}% | {ds.get('toggle_score', 0):.2f}% |\n")
        f.write("\n## 2. RTL Core & Peripheral Modules Coverage\n\n")
        f.write("| Module File | Best Testbench Source | Stmt % | Branch % | Cond % | Toggle % |\n")
        f.write("| :--- | :--- | :---: | :---: | :---: | :---: |\n")
        for m in summary_table:
            f.write(f"| `{m['module']}` | `{m['best_tb']}` | **{m['stmt']:.2f}%** | **{m['branch']:.2f}%** | **{m['cond']:.2f}%** | **{m['toggle']:.2f}%** |\n")

    print(f"\n[INFO] Saved coverage summary to {summary_md_path}")


if __name__ == "__main__":
    main()
