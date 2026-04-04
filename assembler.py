# File: assembler.py
# Kịch bản: Stress Test bằng kỹ thuật Loop Unrolling (Trải phẳng vòng lặp)

import sys

OPCODES = {
    "R_ALU0": "0000", "R_ALU1": "0001", "R_SHIFT": "0010",
    "addi": "0011", "slti": "0100", "bneq": "0101", "bgtz": "0110",
    "j": "0111", "lh": "1000", "sh": "1001", "mfhi": "1010", "hlt": "1111"
}

FUNCTS = {
    "add":  ("R_ALU1", "000"), "sub":  ("R_ALU1", "001"),
    "mult": ("R_ALU1", "010"), "div":  ("R_ALU1", "011"),
    "slt":  ("R_ALU1", "100"), "seq":  ("R_ALU1", "101"), "sltu": ("R_ALU1", "110"), "jr":   ("R_ALU1", "111"),
    "addu": ("R_ALU0", "000"), "subu": ("R_ALU0", "001"), "multu":("R_ALU0", "010"), "divu": ("R_ALU0", "011"),
    "and":  ("R_ALU0", "100"), "or":   ("R_ALU0", "101"), "nor":  ("R_ALU0", "110"), "xor":  ("R_ALU0", "111"),
    "shr":  ("R_SHIFT", "000"), "shl": ("R_SHIFT", "001"), "ror": ("R_SHIFT", "010"), "rol": ("R_SHIFT", "011")
}

def reg_to_bin(reg_str):
    reg_num = int(reg_str.replace('$', '').replace(',', ''))
    return format(reg_num, '03b')

def imm_to_bin(imm_str, bits):
    imm = int(imm_str.replace(',', ''))
    if imm < 0: imm = (1 << bits) + imm
    return format(imm, f'0{bits}b')

def assemble(asm_code):
    machine_code = []
    for line in asm_code.split('\n'):
        clean_line = line.split('#')[0].strip()
        if not clean_line: continue
            
        parts = clean_line.split()
        inst = parts[0].lower()
        
        if inst in FUNCTS: 
            op_group, funct = FUNCTS[inst]
            opcode = OPCODES[op_group]
            if inst == "jr":
                rs = reg_to_bin(parts[1])
                machine_code.append(f"{opcode}{rs}000000{funct}")
            else:
                rd = reg_to_bin(parts[1])
                rs = reg_to_bin(parts[2])
                rt = reg_to_bin(parts[3])
                machine_code.append(f"{opcode}{rs}{rt}{rd}{funct}")
                
        elif inst in ["addi", "slti"]:
            opcode = OPCODES[inst]
            rt = reg_to_bin(parts[1])
            rs = reg_to_bin(parts[2])
            imm = imm_to_bin(parts[3], 6)
            machine_code.append(f"{opcode}{rs}{rt}{imm}")
            
        elif inst in ["lh", "sh"]:
            opcode = OPCODES[inst]
            rt = reg_to_bin(parts[1])
            offset_rs = parts[2].split('(')
            imm = imm_to_bin(offset_rs[0], 6)
            rs = reg_to_bin(offset_rs[1].replace(')', ''))
            machine_code.append(f"{opcode}{rs}{rt}{imm}")
            
        elif inst in ["bneq", "bgtz"]:
            opcode = OPCODES[inst]
            if inst == "bgtz":
                rs = reg_to_bin(parts[1])
                imm = imm_to_bin(parts[2], 6)
                machine_code.append(f"{opcode}{rs}000{imm}")
            else:
                rs = reg_to_bin(parts[1])
                rt = reg_to_bin(parts[2])
                imm = imm_to_bin(parts[3], 6)
                machine_code.append(f"{opcode}{rs}{rt}{imm}")
                
        elif inst == "hlt":
            machine_code.append("1111000000000000")
            
        else:
            print(f"Lỗi: Không nhận diện được lệnh '{inst}'")
            continue

    return [format(int(bin_str, 2), '04X') for bin_str in machine_code]

# ================= MÃ ASSEMBLY KIỂM THỬ THỰC TẾ =================
# Dùng Python để tự động sinh hàng trăm dòng mã Assembly

asm_source = """
# Khởi tạo các thanh ghi ban đầu
addi $1, $0, 0     # Bộ đếm (i)
addi $2, $0, 0     # Tổng cộng dồn (+)
addi $3, $0, 0     # Tổng trừ dồn (-)
addi $7, $0, -1    # $7 = 0xFFFF (Địa chỉ I/O LED ngoại vi)
"""

# TỰ ĐỘNG SINH 50 KHỐI LỆNH TÍNH TOÁN LIÊN TIẾP (MỖI KHỐI 4 LỆNH)
for i in range(1, 51):
    asm_source += f"""
# --- Tính toán block thứ {i} ---
addi $1, $1, 1      # Tăng $1 thêm 1
add  $2, $2, $1     # $2 = $2 + $1
sub  $3, $3, $1     # $3 = $3 - $1
sh   $2, 0($7)      # Bắn kết quả $2 ra đèn LED ngoại vi liên tục
"""

# Chốt lại bằng lệnh dừng CPU
asm_source += "\nhlt\n"

print("Đang biên dịch Assembly...")
hex_output = assemble(asm_source)

with open("program_full.hex", "w") as f:
    for h in hex_output:
        f.write(h + '\n')
print(f"Đã tạo file program_full.hex thành công với {len(hex_output)} dòng lệnh (Machine Codes)!")