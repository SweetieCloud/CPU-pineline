#!/usr/bin/env python3
"""
=============================================================================
STANDALONE RV32IM ASSEMBLER & VERILOG HEX GENERATOR
=============================================================================
Assembles RISC-V RV32IM assembly source files into 32-bit word hex files
compatible with Verilog $readmemh.
Author: Digital IC & Verification Lead Co-pilot
=============================================================================
"""

import sys
import re

REG_MAP = {
    'zero': 0, 'ra': 1, 'sp': 2, 'gp': 3, 'tp': 4,
    't0': 5, 't1': 6, 't2': 7, 's0': 8, 'fp': 8, 's1': 9,
    'a0': 10, 'a1': 11, 'a2': 12, 'a3': 13, 'a4': 14, 'a5': 15,
    'a6': 16, 'a7': 17, 's2': 18, 's3': 19, 's4': 20, 's5': 21,
    's6': 22, 's7': 23, 's8': 24, 's9': 25, 's10': 26, 's11': 27,
    't3': 28, 't4': 29, 't5': 30, 't6': 31
}
for i in range(32):
    REG_MAP[f'x{i}'] = i

def parse_reg(s):
    s = s.strip().rstrip(',')
    if s in REG_MAP:
        return REG_MAP[s]
    raise ValueError(f"Unknown register: '{s}'")

def parse_imm(s, labels=None, current_pc=0):
    s = s.strip().rstrip(',')
    if labels and s in labels:
        return labels[s]
    if s.startswith('0x') or s.startswith('0X') or s.startswith('-0x') or s.startswith('-0X'):
        return int(s, 16)
    return int(s)

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return ((funct7 & 0x7F) << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_i(imm, rs1, funct3, rd, opcode):
    imm = imm & 0xFFF
    return (imm << 20) | ((rs1 & 0x1F) << 15) | ((funct3 & 0x7) << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0xFFF
    imm_11_5 = (imm >> 5) & 0x7F
    imm_4_0 = imm & 0x1F
    return (imm_11_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | (imm_4_0 << 7) | (opcode & 0x7F)

def encode_b(imm, rs2, rs1, funct3, opcode):
    imm = imm & 0x1FFF
    b12 = (imm >> 12) & 0x1
    b11 = (imm >> 11) & 0x1
    b10_5 = (imm >> 5) & 0x3F
    b4_1 = (imm >> 1) & 0xF
    return (b12 << 31) | (b10_5 << 25) | ((rs2 & 0x1F) << 20) | ((rs1 & 0x1F) << 15) | \
           ((funct3 & 0x7) << 12) | (b4_1 << 8) | (b11 << 7) | (opcode & 0x7F)

def encode_u(imm, rd, opcode):
    imm = (imm >> 12) & 0xFFFFF
    return (imm << 12) | ((rd & 0x1F) << 7) | (opcode & 0x7F)

def encode_j(imm, rd, opcode):
    imm = imm & 0x1FFFFF
    j20 = (imm >> 20) & 0x1
    j10_1 = (imm >> 1) & 0x3FF
    j11 = (imm >> 11) & 0x1
    j19_12 = (imm >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | \
           ((rd & 0x1F) << 7) | (opcode & 0x7F)

def parse_mem_operand(op):
    # Matches imm(rs1) e.g. 4(sp) or 0(x1) or label
    m = re.match(r'^(-?\w+)\s*\(\s*(\w+)\s*\)$', op.strip())
    if m:
        return m.group(1), m.group(2)
    raise ValueError(f"Invalid memory operand: '{op}'")

def assemble(source_text):
    # Pass 1: Remove comments, expand macros/pseudo-ops, find labels
    raw_lines = source_text.splitlines()
    instructions = []
    labels = {}
    pc = 0

    clean_lines = []
    for line in raw_lines:
        line = re.sub(r'#.*$', '', line)
        line = re.sub(r'//.*$', '', line).strip()
        if not line:
            continue
        clean_lines.append(line)

    expanded_lines = []
    for line in clean_lines:
        # Check if line contains a valid label at start: label: [rest]
        label_match = re.match(r'^\s*([a-zA-Z_0-9\.\$]+)\s*:(.*)$', line)
        if label_match:
            label = label_match.group(1).strip()
            expanded_lines.append(('label', label))
            rest = label_match.group(2).strip()
            if rest:
                if rest.startswith('.'):
                    expanded_lines.append(('directive', rest))
                else:
                    expanded_lines.append(('instr', rest))
        elif line.startswith('.'):
            # Directives
            expanded_lines.append(('directive', line))
        else:
            expanded_lines.append(('instr', line))

    # Pass 2: Calculate PC positions and expand pseudo-instructions
    final_items = [] # (pc, item_type, content)
    curr_pc = 0

    for item_type, content in expanded_lines:
        if item_type == 'label':
            labels[content] = curr_pc
        elif item_type == 'directive':
            if content.startswith('.word'):
                vals = [v.strip() for v in content[5:].split(',')]
                for v in vals:
                    final_items.append((curr_pc, 'word', v))
                    curr_pc += 4
            elif content.startswith('.string') or content.startswith('.asciz'):
                s_match = re.search(r'"(.*)"', content)
                if s_match:
                    raw_str = s_match.group(1)
                    s_bytes = bytes(raw_str, "utf-8").decode("unicode_escape").encode("utf-8") + b'\x00'
                    while len(s_bytes) % 4 != 0:
                        s_bytes += b'\x00'
                    for i in range(0, len(s_bytes), 4):
                        word_val = int.from_bytes(s_bytes[i:i+4], 'little')
                        final_items.append((curr_pc, 'raw_word', word_val))
                        curr_pc += 4
        elif item_type == 'instr':
            tokens = re.split(r'[\s,]+', content.strip())
            op = tokens[0].lower()
            args = tokens[1:]

            if op == 'nop':
                final_items.append((curr_pc, 'asm', ('addi', ['x0', 'x0', '0'])))
                curr_pc += 4
            elif op == 'mv':
                final_items.append((curr_pc, 'asm', ('addi', [args[0], args[1], '0'])))
                curr_pc += 4
            elif op == 'not':
                final_items.append((curr_pc, 'asm', ('xori', [args[0], args[1], '-1'])))
                curr_pc += 4
            elif op == 'neg':
                final_items.append((curr_pc, 'asm', ('sub', [args[0], 'x0', args[1]])))
                curr_pc += 4
            elif op == 'j':
                final_items.append((curr_pc, 'asm', ('jal', ['x0', args[0]])))
                curr_pc += 4
            elif op == 'jr':
                final_items.append((curr_pc, 'asm', ('jalr', ['x0', args[0], '0'])))
                curr_pc += 4
            elif op == 'ret':
                final_items.append((curr_pc, 'asm', ('jalr', ['x0', 'ra', '0'])))
                curr_pc += 4
            elif op == 'call':
                final_items.append((curr_pc, 'asm', ('jal', ['ra', args[0]])))
                curr_pc += 4
            elif op == 'li':
                # Load Immediate (expand to lui + addi if needed)
                rd = args[0]
                val_str = args[1]
                # Check if immediate is small
                try:
                    val = int(val_str, 0)
                    if -2048 <= val < 2048:
                        final_items.append((curr_pc, 'asm', ('addi', [rd, 'x0', str(val)])))
                        curr_pc += 4
                    else:
                        hi = (val + 0x800) >> 12
                        lo = val - (hi << 12)
                        final_items.append((curr_pc, 'asm', ('lui', [rd, str(hi)])))
                        curr_pc += 4
                        final_items.append((curr_pc, 'asm', ('addi', [rd, rd, str(lo)])))
                        curr_pc += 4
                except ValueError:
                    # Treat as label or symbolic
                    final_items.append((curr_pc, 'asm', ('li_symbolic', [rd, val_str])))
                    curr_pc += 8 # lui + addi
            elif op == 'la':
                rd = args[0]
                sym = args[1]
                final_items.append((curr_pc, 'asm', ('la_symbolic', [rd, sym])))
                curr_pc += 8 # lui + addi
            else:
                final_items.append((curr_pc, 'asm', (op, args)))
                curr_pc += 4

    # Pass 3: Encode instructions
    machine_code = {} # pc -> 32-bit int

    for curr_pc, item_type, content in final_items:
        if item_type == 'raw_word':
            machine_code[curr_pc] = content
        elif item_type == 'word':
            val = parse_imm(content, labels, curr_pc)
            machine_code[curr_pc] = val & 0xFFFFFFFF
        elif item_type == 'asm':
            op, args = content

            if op == 'la_symbolic' or op == 'li_symbolic':
                rd = parse_reg(args[0])
                target = parse_imm(args[1], labels, curr_pc)
                hi = ((target + 0x800) >> 12) & 0xFFFFF
                lo = target & 0xFFF
                if lo >= 2048:
                    lo -= 4096
                word1 = encode_u(hi << 12, rd, 0x37) # lui
                word2 = encode_i(lo, rd, 0x0, rd, 0x13) # addi
                machine_code[curr_pc] = word1
                machine_code[curr_pc + 4] = word2
                continue

            # R-type ALU
            r_map = {
                'add':  (0x00, 0x0, 0x33), 'sub':  (0x20, 0x0, 0x33),
                'sll':  (0x00, 0x1, 0x33), 'slt':  (0x00, 0x2, 0x33),
                'sltu': (0x00, 0x3, 0x33), 'xor':  (0x00, 0x4, 0x33),
                'srl':  (0x00, 0x5, 0x33), 'sra':  (0x20, 0x5, 0x33),
                'or':   (0x00, 0x6, 0x33), 'and':  (0x00, 0x7, 0x33),
                # M-Extension
                'mul':    (0x01, 0x0, 0x33), 'mulh':   (0x01, 0x1, 0x33),
                'mulhsu': (0x01, 0x2, 0x33), 'mulhu':  (0x01, 0x3, 0x33),
                'div':    (0x01, 0x4, 0x33), 'divu':   (0x01, 0x5, 0x33),
                'rem':    (0x01, 0x6, 0x33), 'remu':   (0x01, 0x7, 0x33)
            }
            if op in r_map:
                f7, f3, opc = r_map[op]
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                rs2 = parse_reg(args[2])
                machine_code[curr_pc] = encode_r(f7, rs2, rs1, f3, rd, opc)
                continue

            # I-type ALU
            i_map = {
                'addi':  (0x0, 0x13), 'slti':  (0x2, 0x13), 'sltiu': (0x3, 0x13),
                'xori':  (0x4, 0x13), 'ori':   (0x6, 0x13), 'andi':  (0x7, 0x13),
                'slli':  (0x1, 0x13), 'srli':  (0x5, 0x13), 'srai':  (0x5, 0x13)
            }
            if op in i_map:
                f3, opc = i_map[op]
                rd = parse_reg(args[0])
                rs1 = parse_reg(args[1])
                imm = parse_imm(args[2], labels, curr_pc)
                if op == 'srai':
                    imm = (imm & 0x1F) | 0x400
                elif op in ('slli', 'srli'):
                    imm = imm & 0x1F
                machine_code[curr_pc] = encode_i(imm, rs1, f3, rd, opc)
                continue

            # Loads
            load_map = {'lb': 0x0, 'lh': 0x1, 'lw': 0x2, 'lbu': 0x4, 'lhu': 0x5}
            if op in load_map:
                f3 = load_map[op]
                rd = parse_reg(args[0])
                imm_str, rs1_str = parse_mem_operand(args[1])
                imm = parse_imm(imm_str, labels, curr_pc)
                rs1 = parse_reg(rs1_str)
                machine_code[curr_pc] = encode_i(imm, rs1, f3, rd, 0x03)
                continue

            # Stores
            store_map = {'sb': 0x0, 'sh': 0x1, 'sw': 0x2}
            if op in store_map:
                f3 = store_map[op]
                rs2 = parse_reg(args[0])
                imm_str, rs1_str = parse_mem_operand(args[1])
                imm = parse_imm(imm_str, labels, curr_pc)
                rs1 = parse_reg(rs1_str)
                machine_code[curr_pc] = encode_s(imm, rs2, rs1, f3, 0x23)
                continue

            # Branches
            b_map = {'beq': 0x0, 'bne': 0x1, 'blt': 0x4, 'bge': 0x5, 'bltu': 0x6, 'bgeu': 0x7}
            if op in b_map:
                f3 = b_map[op]
                rs1 = parse_reg(args[0])
                rs2 = parse_reg(args[1])
                target = parse_imm(args[2], labels, curr_pc)
                offset = target - curr_pc
                machine_code[curr_pc] = encode_b(offset, rs2, rs1, f3, 0x63)
                continue

            # Upper Immediates
            if op == 'lui':
                rd = parse_reg(args[0])
                imm = parse_imm(args[1], labels, curr_pc)
                machine_code[curr_pc] = encode_u(imm << 12, rd, 0x37)
                continue
            if op == 'auipc':
                rd = parse_reg(args[0])
                imm = parse_imm(args[1], labels, curr_pc)
                machine_code[curr_pc] = encode_u(imm << 12, rd, 0x17)
                continue

            # Jumps
            if op == 'jal':
                if len(args) == 1:
                    rd = 1 # ra
                    target = parse_imm(args[0], labels, curr_pc)
                else:
                    rd = parse_reg(args[0])
                    target = parse_imm(args[1], labels, curr_pc)
                offset = target - curr_pc
                machine_code[curr_pc] = encode_j(offset, rd, 0x6F)
                continue
            if op == 'jalr':
                rd = parse_reg(args[0])
                if len(args) == 2:
                    imm_str, rs1_str = parse_mem_operand(args[1])
                    imm = parse_imm(imm_str, labels, curr_pc)
                    rs1 = parse_reg(rs1_str)
                else:
                    rs1 = parse_reg(args[1])
                    imm = parse_imm(args[2], labels, curr_pc)
                machine_code[curr_pc] = encode_i(imm, rs1, 0x0, rd, 0x67)
                continue

            # System & CSR
            CSR_MAP = {
                'mstatus': 0x300, 'misa': 0x301, 'mie': 0x304, 'mtvec': 0x305,
                'mscratch': 0x340, 'mepc': 0x341, 'mcause': 0x342, 'mtval': 0x343,
                'mip': 0x344, 'mcycle': 0xC00, 'minstret': 0xC02, 'mcycleh': 0xC80, 'minstreth': 0xC82
            }
            if op == 'ecall':
                machine_code[curr_pc] = 0x00000073
                continue
            if op == 'ebreak':
                machine_code[curr_pc] = 0x00100073
                continue
            if op == 'mret':
                machine_code[curr_pc] = 0x30200073
                continue
            if op == 'wfi':
                machine_code[curr_pc] = 0x10500073
                continue
            if op == 'fence.i':
                machine_code[curr_pc] = 0x0000100F
                continue
            if op == 'fence':
                machine_code[curr_pc] = 0x0FF0000F
                continue

            csr_inst_map = {
                'csrrw': 0x1, 'csrrs': 0x2, 'csrrc': 0x3,
                'csrrwi': 0x5, 'csrrsi': 0x6, 'csrrci': 0x7
            }
            if op in csr_inst_map:
                f3 = csr_inst_map[op]
                rd = parse_reg(args[0])
                csr_str = args[1].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                if op.endswith('i'):
                    uimm = int(args[2], 0) & 0x1F
                    machine_code[curr_pc] = encode_i(csr_addr, uimm, f3, rd, 0x73)
                else:
                    rs1 = parse_reg(args[2])
                    machine_code[curr_pc] = encode_i(csr_addr, rs1, f3, rd, 0x73)
                continue

            # CSR Pseudo instructions
            if op == 'csrw':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                rs1 = parse_reg(args[1])
                machine_code[curr_pc] = encode_i(csr_addr, rs1, 0x1, 0, 0x73) # csrrw x0, csr, rs1
                continue
            if op == 'csrs':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                rs1 = parse_reg(args[1])
                machine_code[curr_pc] = encode_i(csr_addr, rs1, 0x2, 0, 0x73) # csrrs x0, csr, rs1
                continue
            if op == 'csrc':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                rs1 = parse_reg(args[1])
                machine_code[curr_pc] = encode_i(csr_addr, rs1, 0x3, 0, 0x73) # csrrc x0, csr, rs1
                continue
            if op == 'csrr':
                rd = parse_reg(args[0])
                csr_str = args[1].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                machine_code[curr_pc] = encode_i(csr_addr, 0, 0x2, rd, 0x73) # csrrs rd, csr, x0
                continue
            if op == 'csrwi':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                uimm = int(args[1], 0) & 0x1F
                machine_code[curr_pc] = encode_i(csr_addr, uimm, 0x5, 0, 0x73)
                continue
            if op == 'csrsi':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                uimm = int(args[1], 0) & 0x1F
                machine_code[curr_pc] = encode_i(csr_addr, uimm, 0x6, 0, 0x73)
                continue
            if op == 'csrci':
                csr_str = args[0].lower()
                csr_addr = CSR_MAP.get(csr_str, int(csr_str, 0) if csr_str.startswith('0x') or csr_str.isdigit() else 0)
                uimm = int(args[1], 0) & 0x1F
                machine_code[curr_pc] = encode_i(csr_addr, uimm, 0x7, 0, 0x73)
                continue

            raise ValueError(f"Unsupported instruction: '{op}' at PC 0x{curr_pc:08X}")

    return machine_code

def main():
    if len(sys.argv) < 3:
        print("Usage: python rv32im_assembler.py <input.s> <output.hex> [max_words]")
        sys.exit(1)

    src_file = sys.argv[1]
    hex_file = sys.argv[2]
    max_words = int(sys.argv[3]) if len(sys.argv) > 3 else 4096

    with open(src_file, 'r', encoding='utf-8') as f:
        src = f.read()

    machine_code = assemble(src)
    max_pc = max(machine_code.keys()) if machine_code else 0
    num_words = (max_pc // 4) + 1

    words = [0] * max(num_words, 16)
    for pc, code in machine_code.items():
        idx = pc // 4
        if idx < len(words):
            words[idx] = code & 0xFFFFFFFF

    with open(hex_file, 'w', encoding='utf-8') as f:
        for w in words:
            f.write(f"{w:08x}\n")

    print(f"[RV32IM Assembler] Successfully assembled {len(machine_code)} instructions ({len(words)} words) to {hex_file}")

if __name__ == '__main__':
    main()
