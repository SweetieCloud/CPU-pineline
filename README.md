# 🚀 16-bit Pipelined RISC Processor & Custom Toolchain

![Verilog](https://img.shields.io/badge/Language-Verilog_HDL-blue.svg)
![FPGA](https://img.shields.io/badge/Platform-Xilinx_Vivado-orange.svg)
![Python](https://img.shields.io/badge/Toolchain-Python_3-yellow.svg)
![Status](https://img.shields.io/badge/Status-Verified_&_Tested-brightgreen.svg)

## 📌 Overview
A fully synchronous, 5-stage pipelined 16-bit RISC microprocessor designed from scratch in **Verilog HDL**. This project goes beyond basic CPU design by implementing industrial-standard features such as **Hardware Hazard Resolution** (Forwarding & Flushing), **Memory-Mapped I/O**, and an automated **Self-Checking Verification Environment**. 

To bridge the gap between hardware and software, this project includes a **Custom Python Assembler** that compiles high-level algorithmic assembly into machine hex code.

## ✨ Key Features
* **5-Stage Pipeline Architecture:** Instruction Fetch (IF), Decode (ID), Execute (EX), Memory (MEM), and Write-Back (WB).
* **Advanced Hazard Resolution:** * **Forwarding Unit:** Resolves EX and MEM data hazards, including double-hazard prioritization and Zero-register bypass.
* **Hazard Detection Unit:** Implements Load-Use stalling and Branch flushing (predict-not-taken).
* **Memory-Mapped I/O:** Physical peripherals (e.g., LEDs, Switches) are directly mapped to specific memory addresses (e.g., `0xFFFF`), demonstrating bare-metal embedded concepts.
* **Custom Software Toolchain:** A dedicated Python-based assembler (`assembler.py`) with support for loop unrolling, automated binary translation, and inline comments.
* **Robust Verification:** Fully automated testbenches featuring watchdog timers and golden-reference cross-checking. Verified under extreme stress-test algorithms (e.g., Fibonacci generation over 50+ continuous loops).

## 🏗️ System Architecture

*(Please upload a Block Diagram of your Datapath here, e.g., `docs/datapath_diagram.png`)*
### Core Modules
* `cpu_top.v`: Top-level wrapper with Clock Enable (CE) mechanism and I/O routing.
* `datapath.v`: Connects all 5 pipeline stages securely with synchronous registers.
* `control_unit.v`: Decodes 16-bit instructions into pipeline control signals.
* `alu.v`: Performs arithmetic/logic operations, handles Memory Address calculation, and evaluates Branch conditions (Zero, Negative, Overflow flags).
* `hazard_unit.v` & `forwarding_unit.v`: The brain of pipeline synchronization.

## 📜 Instruction Set Architecture (ISA)
This core implements a custom 16-bit instruction set inspired by the MIPS architecture.

| Type   | Format (16 bits)                           | Supported Instructions |
| :---   | :---                                       | :--- |
| **R** | `Opcode(4) \| rs(3) \| rt(3) \| rd(3) \| funct(3)` | `add`, `sub`, `and`, `or`, `slt`, `shl`, `shr`, `jr` |
| **I** | `Opcode(4) \| rs(3) \| rt(3) \| imm(6)`          | `addi`, `slti`, `lh`, `sh`, `bneq`, `bgtz` |
| **J** | `Opcode(4) \| address(12)`                     | `j` (Jump) |
| **Sp** | `Opcode(4) \| 000000000000`                | `hlt` (Halt execution) |

## 🛠️ Toolchain: Custom Python Assembler
Writing machine code by hand is error-prone. This repository includes `assembler.py`, a custom compiler that translates Assembly into Verilog-ready Hex files.

**Example Usage:**
```bash
python assembler.py
```
Input (Assembly):
```bash
# Fibonacci Sequence Generator with Memory-Mapped I/O
addi $1, $0, 0     # Init F(n-1)
addi $2, $0, 1     # Init F(n)
addi $7, $0, -1    # Load I/O Address (0xFFFF)

add  $3, $1, $2    # Calculate next Fibo
sh   $3, 0($7)     # Output to physical LEDs
```

## 🧪 Simulation & Verification

The verification environment avoids manual waveform inspection by using **Directed Self-Checking Testbenches**.

* **Unit Tests:** Isolated testing for `alu.v`, `register_file.v` (checking Zero-register protection), and `forwarding_unit.v`.
* **Integration Test** (`cpu_tb.v`): Runs a stress-test program (Fibonacci sequence over 50 iterations)
  * Cross-checks internal register states and memory outputs against a Golden Reference upon CPU Halt.
  * Prints `[PASSED]` or `[FAILED]` directly to the TCL Console.

---

**How to Run (Xilinx Vivado)**

1. Clone this repository.

2. Add all `.v` files in the `src/ directory` to your Vivado project.

3. Run `assembler.py` to generate `program_full.hex`.

4. Add `cpu_tb.v` as the top-level simulation source.

5. Run Behavioral Simulation.

---

*Building this CPU from logic gates to the assembler toolchain has profoundly deepened my understanding of Embedded Systems, Real-Time Processing, and Hardware-Software Co-design.*
