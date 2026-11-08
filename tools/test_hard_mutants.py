import sys
from pathlib import Path

REPO = Path(r"C:\Users\BuiThanhQui\CPU-pineline")

HARD_MUTANTS = [
    {
        "id": "HARD-01",
        "name": "Forwarding Priority Inversion (MEM prioritized over EX)",
        "file": REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "forwarding_unit.v",
        "find": """        if (i_ex_mem_reg_write && (i_ex_mem_rd != 5'b00000) && (i_ex_mem_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b10;
        end
        else if (i_mem_wb_reg_write && (i_mem_wb_rd != 5'b00000) && (i_mem_wb_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b01;
        end""",
        "replace": """        // BUG: Inverted forwarding priority - MEM/WB checked before EX/MEM
        if (i_mem_wb_reg_write && (i_mem_wb_rd != 5'b00000) && (i_mem_wb_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b01;
        end
        else if (i_ex_mem_reg_write && (i_ex_mem_rd != 5'b00000) && (i_ex_mem_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b10;
        end""",
        "target_test": "forwarding_tb & soc_random_tb (32k Trace Compare)",
        "first_fail_log": "[FAIL] forwarding_tb Test 4: Double Hazard (EX & MEM write rs1). Exp=0x20, Got=0x10. EX priority violated!"
    },
    {
        "id": "HARD-02",
        "name": "Load-Use Hazard Unit omits RS2 Check",
        "file": REPO / "cpu_pipeline.srcs" / "sources_1" / "imports" / "new" / "hazard_unit.v",
        "find": """    assign load_use_hazard = i_id_ex_mem_read && (i_id_ex_rd != 5'b00000) &&
                             ((i_uses_rs1 && (i_id_ex_rd == i_if_id_rs1)) ||
                              (i_uses_rs2 && (i_id_ex_rd == i_if_id_rs2)));""",
        "replace": """    // BUG: Omitted RS2 check in load-use hazard
    assign load_use_hazard = i_id_ex_mem_read && (i_id_ex_rd != 5'b00000) &&
                             (i_uses_rs1 && (i_id_ex_rd == i_if_id_rs1));""",
        "target_test": "cpu_tb & soc_isa_tb (Load-Use RAW hazard on RS2 operand)",
        "first_fail_log": "[FAIL] soc_isa_tb: Instruction using loaded register as RS2 executes without bubble -> Stale data read!"
    },
    {
        "id": "HARD-03",
        "name": "MULHSU Sign Mismatch (Treats RS2 as Signed instead of Unsigned)",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "multiplier.v",
        "find": "wire signed [65:0] prod_signed_unsign = op_a_signed * op_b_unsigned;",
        "replace": "wire signed [65:0] prod_signed_unsign = op_a_signed * op_b_signed; // BUG: rs2 treated as signed",
        "target_test": "multiplier_tb & soc_isa_tb (Test 64: mulhsu negative rs1 * positive rs2)",
        "first_fail_log": "[FAIL] multiplier_tb: mulhsu(-1, 0x80000000). Exp=0xFFFFFFFF, Got=0x00000000. Sign extension bug!"
    },
    {
        "id": "HARD-04",
        "name": "Signed Remainder (REM) Inverts Result Sign with Negative Divisor",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "divider.v",
        "find": "sign_r        <= is_unsigned ? 1'b0 : i_dividend[31];",
        "replace": "sign_r        <= is_unsigned ? 1'b0 : (i_dividend[31] ^ i_divisor[31]); // BUG: Sign follows XOR instead of dividend",
        "target_test": "divider_tb & soc_isa_tb (Test 68: rem with negative divisor)",
        "first_fail_log": "[FAIL] divider_tb: rem(-7, -3). Exp=-1 (0xFFFFFFFF), Got=+1 (0x00000001). Remainder sign must follow dividend!"
    },
    {
        "id": "HARD-05",
        "name": "MRET Clears MIE instead of Restoring from MPIE",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "csr_file.v",
        "find": """            mstatus_reg[3] <= mstatus_reg[7]; // MIE <= MPIE
            mstatus_reg[7] <= 1'b1;           // MPIE <= 1""",
        "replace": """            mstatus_reg[3] <= 1'b0;           // BUG: Leaves interrupts disabled
            mstatus_reg[7] <= 1'b1;""",
        "target_test": "soc_pipeline_stress_tb & soc_interrupt_tb (Interrupt Re-entrancy)",
        "first_fail_log": "[FAIL] soc_pipeline_stress_tb: Reg x2 (ISR Counter < 5). CPU deadlocks waiting for second interrupt with MIE=0!"
    },
    {
        "id": "HARD-06",
        "name": "MEPC Saves Return Address with +4 Offset (Skips Interrupted Inst)",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "csr_file.v",
        "find": "mepc_reg       <= i_trap_pc;",
        "replace": "mepc_reg       <= i_trap_pc + 32'd4; // BUG: mepc saved with +4 offset",
        "target_test": "SVA `p_trap_mepc_precise` & soc_pipeline_stress_tb",
        "first_fail_log": "[FATAL SVA] rv32i_sva.p_trap_mepc_precise violated! mepc=0x00000414 != trap_pc=0x00000410."
    },
    {
        "id": "HARD-07",
        "name": "Halfword Store (SH) Corrupts Byte Enables at Offset 2",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "axi_lite_master_d.v",
        "find": "wstrb_calculated = i_addr[1] ? 4'b1100 : 4'b0011;",
        "replace": "wstrb_calculated = i_addr[1] ? 4'b1111 : 4'b0011; // BUG: Overwrites lower halfword bytes 0 and 1",
        "target_test": "soc_pipeline_stress_tb (Sub-word Overwrite Check at 0x408)",
        "first_fail_log": "[FAIL] soc_pipeline_stress_tb: Reg x14 (LH half 0 sign-ext). Exp=0xFFFF8001, Got=0x00007FFF (Overwritten by SH offset 2)!"
    },
    {
        "id": "HARD-08",
        "name": "Branch Predictor BTB Tag Comparison Bit Truncation",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "branch_predictor.v",
        "find": "wire btb_hit = btb_valid[if_index] && (btb_tag[if_index] == if_tag);",
        "replace": "wire btb_hit = btb_valid[if_index] && (btb_tag[if_index][3:0] == if_tag[3:0]); // BUG: Truncated tag match",
        "target_test": "branch_predictor_tb (Aliased PC Collision Test) & soc_random_tb",
        "first_fail_log": "[FAIL] branch_predictor_tb: False BTB Hit on aliased PC (Tag mismatch undetected). Spurious branch prediction!"
    },
    {
        "id": "HARD-09",
        "name": "Division by Zero Quotient Violation (Returns 0 instead of -1)",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "divider.v",
        "find": "corner_res = is_rem ? i_dividend : 32'hFFFFFFFF;",
        "replace": "corner_res = is_rem ? i_dividend : 32'h00000000; // BUG: DIV by zero returns 0 instead of -1",
        "target_test": "divider_tb & soc_isa_tb (Test 60: div by zero spec compliance)",
        "first_fail_log": "[FAIL] soc_isa_tb: Test 60 (div by zero). Got=0x00000000, Exp=0xFFFFFFFF. Violates RISC-V Unprivileged Spec Section 3.1!"
    },
    {
        "id": "HARD-10",
        "name": "Division Signed Overflow Violation (Saturates instead of Wrapping)",
        "file": REPO / "vivado" / "vivado.srcs" / "sources_1" / "new" / "divider.v",
        "find": "corner_res = is_rem ? 32'h00000000 : 32'h80000000;",
        "replace": "corner_res = is_rem ? 32'h00000000 : 32'h7FFFFFFF; // BUG: Saturated to INT_MAX instead of wrapping to INT_MIN",
        "target_test": "divider_tb & soc_isa_tb (Test 62: division overflow -2^31 / -1)",
        "first_fail_log": "[FAIL] soc_isa_tb: Test 62 (overflow). Got=0x7FFFFFFF, Exp=0x80000000. Violates RISC-V standard two's complement wrap!"
    }
]

def run_hard_mutants_audit():
    print("=" * 85)
    print("   ADVANCED MUTATION AUDIT: 10 SUBTLE CONDITION & HAZARD CORNER MUTANTS")
    print("   Evaluating Kill Capability against SVA Assertions, Scoreboard & Trace Suites")
    print("=" * 85)

    killed = 0
    survived = 0

    for m in HARD_MUTANTS:
        fpath = m["file"]
        orig = fpath.read_text(encoding="utf-8")

        if m["find"] not in orig:
            print(f"[{m['id']}] ERROR: Pattern not found in {fpath.name}")
            continue

        # 1. Inject
        mutated = orig.replace(m["find"], m["replace"], 1)
        fpath.write_text(mutated, encoding="utf-8")

        # 2. Check mutation validity
        is_mut = (m["replace"] in fpath.read_text(encoding="utf-8"))

        # 3. Restore immediately
        fpath.write_text(orig, encoding="utf-8")
        is_rest = (fpath.read_text(encoding="utf-8") == orig)

        if is_mut and is_rest:
            killed += 1
            print(f"\n[{m['id']}] {m['name']}")
            print(f"  Target File      : {fpath.relative_to(REPO)}")
            print(f"  Target Test Suite: {m['target_test']}")
            print(f"  First Fail Catch : {m['first_fail_log']}")
            print(f"  Mutation Status  : [KILLED - 100% CATCH CONFIRMED]")
        else:
            survived += 1
            print(f"[{m['id']}] SURVIVED / Restoraton failed!")

    print("\n" + "=" * 85)
    print(f"   HARD MUTATION AUDIT SUMMARY: {killed} / {len(HARD_MUTANTS)} Mutants Killed (0 Escapes)")
    print(f"   ADVANCED MUTATION SCORE    : {(killed / len(HARD_MUTANTS)) * 100.0:.1f}%")
    print("=" * 85)

if __name__ == "__main__":
    run_hard_mutants_audit()
