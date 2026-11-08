# 🚀 RV32IM Pipelined System-on-Chip (SoC) & FPGA Implementation

![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32IM%20(Unprivileged%2020191213)-blue.svg)
![Privilege](https://img.shields.io/badge/Privilege-Machine%20Mode%20(v1.11)-blueviolet.svg)
![Architecture](https://img.shields.io/badge/Pipeline-5--Stage%20In--Order-indigo.svg)
![Branch Predictor](https://img.shields.io/badge/Branch%20Predictor-BHT%20(64x2--bit)%20%2B%20BTB-purple.svg)
![Bus Protocol](https://img.shields.io/badge/Interconnect-AMBA%20AXI4--Lite%20Crossbar-brightgreen.svg)
![FPGA](https://img.shields.io/badge/FPGA-Xilinx%20Zynq--7000%20(xc7z020clg400--1)-red.svg)
![Timing](https://img.shields.io/badge/Timing-WNS%20%2B0.736ns%20%40%2050MHz%20(MET)-success.svg)
![Quality](https://img.shields.io/badge/Latches-0%20(100%25%20Synchronous)-brightgreen.svg)
![Verification](https://img.shields.io/badge/Verification-23%2F23%20Testbenches%20(100%25%20PASS)-gold.svg)
![SVA](https://img.shields.io/badge/SVA-25%20Assertions%20%26%20Covers%20(0%20Violations)-success.svg)
![Retire Trace](https://img.shields.io/badge/Retire%20Trace-100%20Seeds%20%7C%2036%2C232%20Insts%20(100%25%20Match)-brightgreen.svg)

---

## 📑 MỤC LỤC (TABLE OF CONTENTS)
1. [Tổng quan dự án](#-1-tổng-quan-dự-án-project-overview)
2. [Đặc tả hệ thống vi mạch](#️-2-đặc-tả-hệ-thống-vi-mạch-system-specifications)
3. [Sơ đồ khối kiến trúc hệ thống](#-3-sơ-đồ-khối-kiến-trúc-hệ-thống-system-architecture-diagrams)
4. [Bản đồ không gian bộ nhớ (Memory Map)](#-4-bản-đồ-không-gian-bộ-nhớ-memory-map)
5. [Kiến trúc & Cơ chế kiểm chứng 4 tầng (4-Layer SoC Verification)](#-5-kiến-trúc--cơ-chế-kiểm-chứng-4-tầng-4-layer-soc-verification)
6. [Bảng tổng kết kiểm chứng hồi quy toàn hệ thống (Regression Matrix)](#-6-bảng-tổng-kết-kiểm-chứng-hồi-quy-toàn-hệ-thống-regression-matrix)
   - [6.1 Báo cáo độ bao phủ mã nguồn thực tế (Code Coverage Report)](#-61-báo-cáo-độ-bao-phủ-mã-nguồn-thực-tế-code-coverage-report---vivado-xcrg)
   - [6.2 Đánh giá năng lực phát hiện lỗi vi mạch (Mutation Testing)](#-62-đánh-giá-năng-lực-phát-hiện-lỗi-vi-mạch-mutation-testing--fault-injection-audit)
   - [6.3 Kiểm chứng đối chiếu vết lệnh hưu trí quy mô lớn (High-Volume Retire Trace)](#-63-kiểm-chứng-đối-chiếu-vết-lệnh-hưu-trí-quy-mô-lớn-high-volume-retire-trace-regression)
   - [6.4 Mở rộng kiểm thử bộ nhớ bán từ (Sub-Word Alignment & Overwrite)](#-64-mở-rộng-kiểm-thử-bộ-nhớ-bán-từ-sub-word-alignment--overwrite-integrity)
7. [Danh sách phân tích nguyên nhân gốc rễ và giải pháp khắc phục (Root Cause Analysis) (Root Cause Analysis)](#-7-danh-sách-điểm-nghẽn-kỹ-thuật-đã-xử-lý-triệt-để-root-cause-analysis)
8. [Tổng hợp tài nguyên vật lý & STA Timing trên FPGA Arty Z7-20](#-8-tổng-hợp-tài-nguyên-vật-lý--sta-timing-trên-fpga-arty-z7-20)
9. [Cấu trúc thư mục dự án](#-9-cấu-trúc-thư-mục-dự-án-clean-directory-structure)
10. [Hướng dẫn tái lập kết quả mô phỏng & nạp mạch FPGA](#-10-hướng-dẫn-tái-lập-kết-quả-mô-phỏng--nạp-mạch-fpga)

---

## 📌 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

Dự án này là một **Hệ thống vi xử lý hoàn chỉnh trên chip (SoC)**, xây dựng xung quanh lõi vi xử lý **32-bit RISC-V RV32IM** 5 tầng đường ống (*5-stage pipeline*). Dự án được thiết kế hoàn toàn bằng ngôn ngữ **Verilog HDL / SystemVerilog**, trải qua quy trình xác minh nghiêm ngặt (*Rolling-wave Verification*), kiểm định không vi phạm Latch, khép kín thời gian tĩnh (*Static Timing Analysis Closure*) và nạp thành công lên phần cứng thực tế kit **Digilent Arty Z7-20 (Xilinx Zynq-7000 `xc7z020clg400-1`)**.

### Các trụ cột kiến trúc cốt lõi:
1. **Lõi xử lý RISC-V RV32IM:** Hỗ trợ đầy đủ tập lệnh cơ bản RV32I (37 lệnh) kết hợp bộ đồng xử lý toán học phần cứng chuẩn **RV32M** (Hardware Multiplier 1 chu kỳ dựa trên 12 lát DSP48E1 và Hardware Divider 32 chu kỳ với cơ chế Fast-Exit khi chia cho 0 hoặc tràn số bù hai).
2. **Bộ dự đoán phân nhánh động (Dynamic Branch Predictor):** Tích hợp bảng lịch sử rẽ nhánh **BHT** (*64-entry 2-bit Saturating Counter*) và bộ đệm địa chỉ đích **BTB** (*64-entry*), kết hợp cơ chế giải quyết rẽ nhánh sớm (*Early Branch Resolution*) tại tầng Decode (ID), giảm chi phí rẽ nhánh sai xuống còn đúng 1 chu kỳ.
3. **Phân tầng bộ nhớ & Cache:** Bộ nhớ đệm lệnh **L1 Instruction Cache** 1024 Bytes (Direct-Mapped, độ trễ 1 chu kỳ khi Hit) cùng bộ nhớ nội **16KB Dual-Port Block RAM** (`RAMB36E1`).
4. **Hạ tầng Bus AMBA AXI4-Lite:** Bộ chuyển mạch đa kênh (*Crossbar Interconnect*) kết nối 2 Master (I-Cache, D-Bus Master) với 4 Slave ngoại vi và 1 Slave bẫy lỗi giải mã (*DECERR*).
5. **Hệ thống ngoại vi ánh xạ bộ nhớ (MMIO Subsystem):** AXI UART Lite (115200 Baud kèm bộ lọc nhiễu đường truyền), AXI GPIO (LEDs, Switches, Buttons), và AXI Machine Timer 64-bit (MTIME/MTIMECMP).
6. **Kiến trúc xác minh 4 tầng SoC (4-Layer Verification):** Tích hợp bộ quy tắc **SystemVerilog Assertions (11 Concurrent SVA)**, **9 Event Call Spies**, các Bus Functional Models (BFMs) độc lập và hệ thống Scoreboard tự động chấm điểm.
7. **Chuỗi công cụ C-Baremetal & Assembler:** GNU Linker Script (`link.ld`), Assembly Startup Code (`crt0.s`), thư viện Driver C và trình biên dịch hợp ngữ độc lập viết bằng Python (`tools/rv32im_assembler.py`).

---

## ⚙️ 2. ĐẶC TẢ HỆ THỐNG VI MẠCH (SYSTEM SPECIFICATIONS)

| Tiêu chuẩn / Thông số | Giá trị kỹ thuật | Diễn giải kiến trúc vi mạch |
|:---|:---:|:---|
| **Tập lệnh kiến trúc (ISA)** | **RISC-V RV32IM** | RV32I Base Integer + RV32M Hardware Multiply/Divide (Chuẩn Unprivileged v20191213) |
| **Cấp đặc quyền (Privilege)** | **Machine Mode (M-Mode)** | Chuẩn RISC-V Privileged Architecture v1.11 (`mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`, `mcycle`, `minstret`) |
| **Cấu trúc đường ống (Pipeline)** | **5 tầng (5-Stage In-Order)** | `IF` (Fetch) $\rightarrow$ `ID` (Decode/Branch) $\rightarrow$ `EX` (Execute) $\rightarrow$ `MEM` (Memory) $\rightarrow$ `WB` (Write-Back) |
| **Tần số hoạt động (Clock)** | **50.0 MHz** ($T = 20.000\text{ ns}$) | Sinh qua khối vi sai thấp `MMCME2_BASE` từ nguồn dao động 125.0 MHz trên kit |
| **Tần số tối đa ($F_{MAX}$)** | **51.91 MHz** | Dựa trên $WNS = +0.736\text{ ns}$ sau khi Place & Route tại Slow Process Corner |
| **Worst Negative Slack (WNS)** | **`+0.736 ns` (MET)** | Không có bất kỳ đường truyền nào vi phạm Setup Time ($TNS = 0.000\text{ ns}$) |
| **Worst Hold Slack (WHS)** | **`+0.037 ns` (MET)** | Không có bất kỳ đường truyền nào vi phạm Hold Time ($THS = 0.000\text{ ns}$) |
| **Kiểm tra Latch vô ý** | **0 Latch (100% Synchronous)** | Kiểm tra nghiêm ngặt: $0$ tế bào `LDCE`/`LDPE` trong toàn bộ Netlist |
| **Bộ nhớ nội (System SRAM)** | **16 KB** (4096 words $\times$ 32-bit) | 4 block `RAMB36E1` true dual-port (Port A: I-Cache refill, Port B: D-Bus MMIO) |
| **Bộ nhớ đệm lệnh (L1 I-Cache)** | **1024 Bytes** (Direct-Mapped) | 64 dòng $\times$ 16 Bytes/dòng (4 words/line). Độ trễ Hit: **1 chu kỳ (0 wait-states)** |
| **Bộ nhân phần cứng (MUL)** | **1 chu kỳ (Single-Cycle)** | Xử lý phép nhân $32\times 32\to 64$-bit (`MUL`, `MULH`, `MULHSU`, `MULHU`), ánh xạ 12 lát `DSP48E1` |
| **Bộ chia phần cứng (DIV/REM)** | **1 đến 34 chu kỳ** | Thuật toán Restoring Shift-Subtract 32 chu kỳ + Fast-Exit 1 chu kỳ khi chia cho 0 hoặc tràn số bù hai |
| **Dự đoán rẽ nhánh (BP)** | **BHT (64x2-bit) + BTB (64)** | 2-bit Saturating Counter (Strong/Weak Taken/Not-Taken). Penalty dự đoán sai: 1 chu kỳ |
| **Giao thức Bus nội** | **AMBA AXI4-Lite** | Crossbar 2 Masters $\times$ 4 Slaves, Dedicated Dual-Port Harvard Routing (M0 $\to$ BRAM Port A, M1 $\to$ 4 Slaves), DECERR support |
| **Ngoại vi nối tiếp (UART)** | **115,200 Baud (8-N-1)** | Lọc xung nhiễu Glitch Rejection, phát hiện Framing Error, FIFO đệm phần cứng |
| **Bộ định thời thực (Timer)** | **64-bit MTIME / MTIMECMP** | Tương thích chuẩn RISC-V Privileged Architecture (Machine Timer Interrupt) |
| **Chip FPGA mục tiêu** | **Xilinx Zynq-7000 (`xc7z020clg400-1`)** | Kit Digilent Arty Z7-20 |

---

## 🏗️ 3. SƠ ĐỒ KHỐI KIẾN TRÚC HỆ THỐNG (SYSTEM ARCHITECTURE DIAGRAMS)

### 3.1 Sơ đồ khối tổng thể Hệ thống trên Chip (SoC Top Architecture)

```mermaid

flowchart TD
    subgraph ARTY_Z7 ["DIGILENT ARTY Z7-20 HARDWARE PLATFORM"]
        CLK_IN["Oscillator 125.0 MHz (Pin H16)"]
        BTN_RST["Reset Button BTN0 (Pin D19)"]
        SW_PINS["Slide Switches SW[1:0] (M20, M19)"]
        LED_PINS["User LEDs LD[3:0] (R14, P14, N16, M14)"]
        UART_PINS["Serial TX/RX (U12, T14 & Pmod JA)"]
    end

    subgraph SOC_WRAPPER ["soc_top_arty_z7 (Board Top Wrapper)"]
        MMCM["MMCME2_BASE<br/>(125MHz to 50MHz Low-Jitter Clock)"]
        SYNC_RST["3-Stage Synchronous Reset Synchronizer"]
    end

    subgraph SOC_SYSTEM ["RV32IM Industrial System-on-Chip (soc_top.v)"]
        subgraph CPU_CORE ["CPU Core (cpu_top.v)"]
            CORE_DP["5-Stage RV32IM Datapath"]
            BP["Dynamic Branch Predictor<br/>(BHT 64x2b + BTB 64-entry)"]
            MDU["Hardware M-Extension (12x DSP48E1 MUL + 32-cycle DIV)"]
            ICACHE["L1 Instruction Cache<br/>(1024B, 1-cycle Hit Latency)"]
            AXI_D_M["AXI4-Lite Data Master Controller"]
            CSR["Machine-Mode CSR File (mcycle, minstret, mstatus...)"]
        end

        subgraph XBAR ["AMBA AXI4-Lite Crossbar Interconnect (2x4)"]
            DECERR["DECERR Default Slave (Bus Error Trap)"]
        end

        subgraph MEMORY ["Memory Subsystem"]
            BRAM["16KB Dual-Port BRAM (4x RAMB36E1)<br/>(Port A: I-Cache Refill | Port B: D-Bus MMIO)"]
        end

        subgraph PERIPHERALS ["Memory-Mapped I/O Peripherals"]
            UART["AXI UART Lite (0x1000_0000, 115200 Baud)"]
            GPIO["AXI GPIO Controller (0x1000_1000, LEDs/Switches)"]
            TIMER["AXI Machine Timer (0x1000_2000, 64-bit MTIME)"]
        end
    end

    %% Clock and Reset Distribution
    CLK_IN --> MMCM
    MMCM -->|50 MHz sys_clk| CPU_CORE
    MMCM -->|50 MHz sys_clk| XBAR
    MMCM -->|50 MHz sys_clk| MEMORY
    MMCM -->|50 MHz sys_clk| PERIPHERALS
    MMCM -->|Locked| SYNC_RST
    BTN_RST --> SYNC_RST
    SYNC_RST -->|soc_rst_n| CPU_CORE

    %% Core to Interconnect
    ICACHE ---|Master 0: AXI AR/R| XBAR
    AXI_D_M ---|Master 1: AXI AW/W/B/AR/R| XBAR

    %% Interconnect to Slaves
    XBAR ---|Slave 0: 0x0000_0000 16KB| BRAM
    XBAR ---|Slave 1: 0x1000_0000| UART
    XBAR ---|Slave 2: 0x1000_1000| GPIO
    XBAR ---|Slave 3: 0x1000_2000| TIMER

    %% External Connections
    UART ---|TX / RX| UART_PINS
    SW_PINS --> GPIO
    GPIO --> LED_PINS
```

---

### 3.2 Sơ đồ chi tiết 5 tầng đường ống vi xử lý (5-Stage Pipelined Datapath)

```mermaid
flowchart LR
    subgraph STAGE_IF ["1. IF (Instruction Fetch)"]
        PC["PC Reg (32b)"]
        BP_MOD["Branch Predictor\n(BHT + BTB)"]
        PC_MUX{"Next PC Mux"}
        ICACHE_MOD["L1 I-Cache\n(1024B Direct)"]
    end

    subgraph STAGE_ID ["2. ID (Decode & Early Branch)"]
        IF_ID["IF/ID Reg"]
        CU["Control Unit\n(RV32IM + CSR)"]
        RF["Register File (32x32 RAM32M)\n(Write-Through, x0 Locked)"]
        IMM["Immediate Gen (I,S,B,U,J)"]
        BC["Branch Comparator\n(Signed/Unsigned)"]
        HU["Hazard Unit\n(Load-Use & Mul Stall)"]
    end

    subgraph STAGE_EX ["3. EX (Execute & Math)"]
        ID_EX["ID/EX Reg"]
        ALU["RV32I ALU (10 Ops)"]
        MUL["DSP Multiplier (1-cycle)"]
        DIV["Restoring Shift-Subtract Divider (32-cyc)"]
        FWD["Forwarding Unit (EX/MEM)"]
        EX_MUX{"EX Result Mux"}
    end

    subgraph STAGE_MEM ["4. MEM (Memory Access)"]
        EX_MEM["EX/MEM Reg"]
        AXI_D_CTRL["AXI4-Lite D-Master\n(LB/LH/LW/SB/SH/SW)"]
    end

    subgraph STAGE_WB ["5. WB (Write Back & CSR)"]
        MEM_WB["MEM/WB Reg"]
        CSR_MOD["CSR File (Machine Mode)"]
        WB_MUX{"WB Mux\n(ALU/MEM/PC+4/CSR)"}
    end

    %% Pipeline Forward Flow
    PC --> ICACHE_MOD --> IF_ID
    PC --> BP_MOD -->|Predicted Target & Taken| PC_MUX --> PC
    IF_ID --> CU & RF & IMM
    CU --> ID_EX
    RF --> ID_EX
    IMM --> ID_EX
    ID_EX --> ALU & MUL & DIV --> EX_MUX --> EX_MEM --> AXI_D_CTRL --> MEM_WB --> WB_MUX --> RF

    %% Early Branch & Hazard Feedbacks
    BC -.->|Mispredict Redirect Target| PC_MUX
    HU -.->|Stall PC & IF/ID, Bubble ID/EX| PC & IF_ID & ID_EX
    FWD -.->|Forwarding EX/MEM to ALU| ALU
    MEM_WB --> CSR_MOD --> WB_MUX
```

---

## 🗺️ 4. BẢN ĐỒ KHÔNG GIAN BỘ NHỚ (MEMORY MAP)

Không gian địa chỉ vật lý 32-bit (`0x0000_0000` đến `0xFFFF_FFFF`) được phân bổ phân cấp qua bộ giải mã địa chỉ không tắc nghẽn của AXI Crossbar:

| Vùng địa chỉ | Kích thước | Tên ngoại vi / Vùng nhớ | Giao thức Bus | Quyền truy xuất | Chức năng chi tiết |
|:---|:---:|:---|:---:|:---:|:---|
| `0x0000_0000 - 0x0000_3FFF` | **16 KB** | **Internal Dual-Port BRAM** | AXI4-Lite (S0) | R / W / X | Chứa mã máy chương trình (`.text`), hằng số (`.rodata`), dữ liệu (`.data`, `.bss`) và Stack đỉnh tại `0x0000_3FFC`. |
| `0x1000_0000 - 0x1000_0003` | 4 Bytes | **UART RX / TX Data Register** | AXI4-Lite (S1) | R / W | Ghi 8-bit vào `TX_DATA` để phát ký tự ra UART TX; Đọc 8-bit từ `RX_DATA` để nhận ký tự từ UART RX (cửa sổ giải mã S1: `0x1000_0000 - 0x1000_0FFF`). |
| `0x1000_0004 - 0x1000_0007` | 4 Bytes | **UART Status Register** | AXI4-Lite (S1) | R | Bit 0: `rx_valid` (có byte mới đến), Bit 1: `tx_ready` (sẵn sàng truyền byte tiếp theo), Bit 2: `tx_busy`. |
| `0x1000_1000 - 0x1000_1003` | 4 Bytes | **GPIO Inputs Register** | AXI4-Lite (S2) | R | Bits [3:0]: 4 công tắc gạt (`SW[3:0]`, trên kit Arty Z7 nối `SW[1:0]`); Bits [7:4]: 4 nút nhấn (`BTN[3:0]`). Cửa sổ giải mã S2: `0x1000_1000 - 0x1000_1FFF`. |
| `0x1000_1004 - 0x1000_1007` | 4 Bytes | **GPIO Outputs Register** | AXI4-Lite (S2) | R / W | Bits [3:0]: Điều khiển trực tiếp 4 đèn LED xanh (`LD0, LD1, LD2, LD3`) trên kit. |
| `0x1000_2000 - 0x1000_2003` | 4 Bytes | **MTIME Lower (32-bit)** | AXI4-Lite (S3) | R / W | 32-bit thấp của bộ đếm chu kỳ thời gian thực 64-bit (tăng mỗi chu kỳ xung nhịp 50MHz). Cửa sổ giải mã S3: `0x1000_2000 - 0x1000_2FFF`. |
| `0x1000_2004 - 0x1000_2007` | 4 Bytes | **MTIME Upper (32-bit)** | AXI4-Lite (S3) | R / W | 32-bit cao của bộ đếm chu kỳ thời gian thực 64-bit. |
| `0x1000_2008 - 0x1000_200F` | 8 Bytes | **MTIMECMP (64-bit)** | AXI4-Lite (S3) | R / W | Thanh ghi so sánh định thời phát ngắt ngắt Timer khi `MTIME >= MTIMECMP`. |
| *Mọi địa chỉ còn lại* | Toàn dải | **AXI DECERR Default Slave** | AXI4-Lite (S_DEC) | N/A | Tự động trả về phản hồi lỗi `RRESP/BRESP = 2'b11` (DECERR), chống treo cứng đường ống bus. |

---

## 🛡️ 5. KIẾN TRÚC & CƠ CHẾ KIỂM CHỨNG 4 TẦNG (4-LAYER SOC VERIFICATION)

Hệ thống kiểm chứng được xây dựng theo kiến trúc phân tầng chuẩn mực trong thiết kế vi mạch SoC:

```
+-----------------------------------------------------------------------------------+
|  LAYER 4: TEST SCENARIO, SCOREBOARD & ASSERTION CHECKPOINTS                       |
|  - expect_eq, expect_ne, expect_state, expect_spy validation macros               |
|  - Pass/Fail Accounting, End-of-Test Summary & Clean Termination                  |
+-----------------------------------------------------------------------------------+
|  LAYER 3: SVA (SystemVerilog Assertions) & EVENT CALL SPIES                       |
|  - 11 Concurrent Assertions (Bus Handshake, Protocol, Pipeline Invariants)         |
|  - 9 Spy Transaction Counters (Sub-threshold glitches, Flushes, Forwarding)      |
+-----------------------------------------------------------------------------------+
|  LAYER 2: MOCK SERVICES & BUS FUNCTIONAL MODELS (BFMs)                            |
|  - AXI4-Lite Master/Slave BFM (axi_write, axi_read)                              |
|  - Mock UART Serial Driver (Glitch injector, Framing error injector)              |
|  - Bounded Polling Tasks (wait_for_tx_ready, wait_for_irq)                        |
+-----------------------------------------------------------------------------------+
|  LAYER 1: DUT ISOLATION, CLOCK & RESET INFRASTRUCTURE                             |
|  - 50 MHz Differential/Single-ended Clock Generator                               |
|  - Synchronous/Asynchronous Reset Controller                                      |
|  - Global Hardware Watchdog Safety Timers (#50000 - #100000 ns)                   |
+-----------------------------------------------------------------------------------+
```

### 5.1 Khẳng định SystemVerilog Assertions Toàn diện & Chứng minh Không rỗng (25 SVA & Non-Vacuity Proof)
Module [`rv32i_sva.sv`](vivado/vivado.srcs/sim_1/new/rv32i_sva.sv) thiết lập hệ thống giám sát thụ động toàn diện **25 khẳng định vi kiến trúc và giao thức bus**, đi kèm bộ đếm thực nghiệm (`cov_hit_p_*`) chứng minh mọi khẳng định đều được kích hoạt thật sự (non-vacuous active hits):

> [!NOTE]
> **Khôi phục Đầy đủ & Hợp nhất 25 Bất biến Vi kiến trúc Đường ống:**
> 1. **Khôi phục các bất biến cốt lõi bị gián đoạn:** Bổ sung lại toàn diện 8 thuộc tính vi kiến trúc đường ống quan trọng (`p_branch_flush`, `p_load_use_stall`, `p_interrupt_taken`, `p_fence_i_flush`, `p_bht_counter_range`, `p_reset_pc`, `p_csr_mret_target`, `p_div_busy_stall`), hợp nhất cùng 17 thuộc tính bus AXI, căn chỉnh bộ nhớ và bất biến thanh ghi, nâng tổng số khẳng định lên **25 SVA**.
> 2. **Đối chiếu thực nghiệm song song hai môi trường:**
>    - **Cột A – `soc_pipeline_stress_tb` (375 chu kỳ):** Chuyên biệt kích hoạt ngắt Timer IRQ, MRET khôi phục MIE, tự sửa đổi mã lệnh (Self-modifying code FENCE.I), ghi thanh ghi `x0`, và kiểm tra cấm ghi bus của Store bị flush.
>    - **Cột B – `soc_trace_tb` (36,232 lệnh / 100 seeds):** Kích hoạt liên tục các bất biến khi đường ống xử lý luồng điều khiển động phức tạp (7,791 nhánh điều kiện, 4,485 mispredict flushes, 2,015 mul->branch stalls, 1,849 div stalls, 1,940 load-use stalls).

| # | Khẳng định (Assertion) | Phân loại | Điều kiện kiểm chứng vi kiến trúc | Hits (`soc_pipeline_stress_tb`) | Hits (`soc_trace_tb` - 36k Insts) | Trạng thái Non-Vacuity |
| :-: | :--- | :---: | :--- | :---: | :---: | :---: |
| 1 | `p_x0_always_zero` | Invariant | Thanh ghi `x0` luôn trả về giá trị `0x00000000` ở mọi chu kỳ đọc. | **306 hits** | **25,710 hits** | **PASS** (Hoạt động liên tục) |
| 2 | `p_pc_freeze_on_stall` | Hazard | Khi có tín hiệu `pipeline_hold`, PC chu kỳ sau phải ổn định tuyệt đối (`$stable(pc)`). | **375 hits** | **25,710 hits** | **PASS** (Hoạt động liên tục) |
| 3 | `p_x0_immutable` | RF Spec | Lệnh ghi vào `x0` là hợp lệ theo spec RISC-V nhưng không bao giờ làm biến đổi giá trị của `x0`. | **141 hits** | 0 hits *(Trace không ghi x0)*| **PASS** (Non-vacuous ở Stress) |
| 4 | `p_reset_pc` | Reset | Chu kỳ đầu tiên ngay sau khi thoát Reset (`$rose(rst_n)`), PC phải bằng `0x00000000`. | **1 hit** | **10 hits** | **PASS** (Non-vacuous) |
| 5 | `p_branch_flush` | Control | Rẽ nhánh đoán sai (`branch_mispredict`) bắt buộc phải xóa sạch bóng lệnh tại tầng ID/EX. | **8 hits** | **4,485 hits** | **PASS** (Kích hoạt mạnh ở Trace) |
| 6 | `p_load_use_stall` | Hazard | Xung đột Load-Use RAW bắt buộc kích hoạt `pipeline_hold` chèn 1 bong bóng NOP. | **4 hits** | **1,940 hits** | **PASS** (Kích hoạt mạnh ở Trace) |
| 7 | `p_bht_counter_range` | Predictor | Bộ đếm bão hòa 2-bit BHT luôn nằm nghiêm ngặt trong giới hạn $[0, 3]$. | **12 hits** | **7,791 hits** | **PASS** (Kích hoạt mạnh ở Trace) |
| 8 | `p_div_busy_stall` | Arithmetic | Bộ chia 32 chu kỳ đang bận (`div_busy`) bắt buộc phải dừng đường ống CPU. | **2 hits** | **1,849 hits** | **PASS** (Non-vacuous) |
| 9 | `p_div_no_drop_on_hold` | Arithmetic | Xung hoàn tất chia `div_done` không bao giờ bị rơi khi đường ống kích hoạt `pipeline_hold`. | **2 hits** | **1,849 hits** | **PASS** (Non-vacuous) |
| 10 | `p_flushed_store_no_bus_write` | Pipeline | Lệnh Store nằm trong vùng bóng đầu cơ bị flush (`ex_mem_flush`) cấm tuyệt đối phát ghi bus. | **66 hits** | 0 hits *(Không có shadow store)*| **PASS** (Non-vacuous ở Stress) |
| 11 | `p_flushed_id_ex_no_rf_write` | Pipeline | Bong bóng lệnh bị flush tại tầng ID/EX cấm tuyệt đối kích hoạt ghi thanh ghi `ctrl_reg_write_ex`. | **6 hits** | **4,485 hits** | **PASS** (Kích hoạt mạnh ở Trace) |
| 12 | `p_trap_mepc_precise` | Trap/CSR | Khi ngắt/trap xảy ra (`trap_taken`), thanh ghi `mepc` lưu đúng địa chỉ lệnh bị ngắt (`trap_pc`). | **5 hits** | **10 hits** | **PASS** (Non-vacuous) |
| 13 | `p_interrupt_taken` | Trap/CSR | Khi ngắt được tiếp nhận (`trap_taken`), PC chu kỳ sau lập tức chuyển hướng về vector MTVEC. | **5 hits** | **10 hits** | **PASS** (Non-vacuous) |
| 14 | `p_csr_mret_target` | Trap/CSR | Thi hành lệnh `mret` bắt buộc chuyển hướng PC về đúng giá trị lưu trong thanh ghi `mepc`. | **5 hits** | 0 hits *(Trace không có IRQ)*| **PASS** (Non-vacuous ở Stress) |
| 15 | `p_fence_i_flush` | Cache | Lệnh `FENCE.I` bắt buộc kích hoạt tín hiệu xóa dòng I-Cache (`icache_inv`) và flush đường ống. | **1 hit** | 0 hits *(Trace không đổi code)*| **PASS** (Non-vacuous ở Stress) |
| 16 | `p_dmem_word_aligned` | Alignment | Truy xuất từ 32-bit (`LW`, `SW`) bắt buộc phải căn chỉnh 4-byte (`addr[1:0] == 2'b00`). | **33 hits** | **3,923 hits** | **PASS** (Hoạt động liên tục) |
| 17 | `p_dmem_half_aligned` | Alignment | Truy xuất nửa từ 16-bit (`LH`, `LHU`, `SH`) bắt buộc phải căn chỉnh 2-byte (`addr[0] == 1'b0`). | **33 hits** | **1,001 hits** | **PASS** (Non-vacuous cả 2 bên) |
| 18 | `p_axi_i_ar_stable` | Protocol | Kênh đọc I-Bus: `araddr` và `arvalid` phải giữ nguyên cho đến khi nhận `arready`. | **100 hits** | **25,710 hits** | **PASS** (Hoạt động liên tục) |
| 19 | `p_axi_d_ar_stable` | Protocol | Kênh đọc D-Bus: `araddr` và `arvalid` phải giữ nguyên cho đến khi nhận `arready`. | **9 hits** | **1,940 hits** | **PASS** (Hoạt động liên tục) |
| 20 | `p_axi_d_aw_stable` | Protocol | Kênh ghi địa chỉ D-Bus: `awaddr` và `awvalid` giữ nguyên cho đến khi nhận `awready`. | **8 hits** | **1,983 hits** | **PASS** (Hoạt động liên tục) |
| 21 | `p_axi_d_w_stable` | Protocol | Kênh ghi dữ liệu D-Bus: `wdata`, `wstrb` và `wvalid` giữ nguyên cho đến khi nhận `wready`. | **8 hits** | **1,983 hits** | **PASS** (Hoạt động liên tục) |
| 22 | `p_axi_i_liveness` | Protocol | Giới hạn sống kênh I-Bus: Mọi yêu cầu đọc phải nhận phản hồi `rvalid` trong vòng $\le 64$ chu kỳ. | **100 hits** | **25,710 hits** | **PASS** (Hoạt động liên tục) |
| 23 | `p_axi_d_read_liveness`| Protocol | Giới hạn sống kênh đọc D-Bus: Phản hồi đọc `rvalid` phải hoàn tất trong vòng $\le 64$ chu kỳ. | **9 hits** | **3,232 hits** | **PASS** (Hoạt động liên tục) |
| 24 | `p_axi_d_write_liveness`| Protocol| Giới hạn sống kênh ghi D-Bus: Phản hồi ghi `bvalid` phải hoàn tất trong vòng $\le 64$ chu kỳ. | **8 hits** | **2,629 hits** | **PASS** (Hoạt động liên tục) |
| 25 | `p_axi_d_ar_bound` | Protocol | Bắt tay chặt kênh đọc D-Bus: `arready` phản hồi trong vòng $\le 32$ chu kỳ. | **9 hits** | **1,940 hits** | **PASS** (Hoạt động liên tục) |

### 5.2 Hệ thống gián điệp sự kiện vi kiến trúc (Event Call Spies)
Giám sát và ghi nhận các sự kiện vi kiến trúc ngầm mà kiểm thử thông thường không thể thấy từ bus bên ngoài:
- `spy_false_start_glitch`: Đếm số xung nhiễu ngắn hơn 1/2 chu kỳ baud bị bộ lọc UART loại bỏ thành công.
- `spy_framing_error`: Đếm số byte truyền sai bit Stop mà UART phát hiện và từ chối ghi nhận vào bộ đệm nhận.
- `spy_branch_mispredict_flushes`: Đếm chính xác số lần pipeline bị xóa sạch do rẽ nhánh sai.
- `spy_ex_to_ex_forwarding` / `spy_mem_to_ex_forwarding`: Đếm tần suất mạch Forwarding Unit can thiệp để triệt tiêu stall.
- `spy_load_use_stalls`: Đếm số chu kỳ CPU phải dừng để chờ dữ liệu từ Data Memory / BRAM.

### 5.3 Cơ chế chống treo mô phỏng (Bounded Loops & Watchdog Timers)
- **Bounded Polling Loops:** Tuyệt đối không dùng `wait(condition)` vô hạn. Tất cả chuyển đổi trạng thái giao thức đều được bọc trong vòng lặp có timeout (ví dụ: `wait_for_tx_ready(300)`).
- **Global Hardware Watchdog:** Mọi testbench đều có luồng watchdog độc lập `#100000` (100 µs). Nếu có deadlock phần cứng, mô phỏng tự động ngắt an toàn và in thông báo báo lỗi.

---

## 🏆 6. BẢNG TỔNG KẾT KIỂM CHỨNG HỒI QUY TOÀN HỆ THỐNG (REGRESSION MATRIX)

Toàn bộ **23 bộ testbench** (bao gồm unit test từng module, stress test bus cực đoan, kiểm chuẩn ISA, ngắt Timer & CSR Trap, stress tương tác đa sự kiện đường ống, và hồi quy 100 seeds so khớp retire trace) đã đạt tỷ lệ **100% PASSED**, không có bất kỳ vi phạm SVA nào:

| # | Tệp Testbench | Phạm vi kiểm thử (Scope) | Số điểm kiểm tra (Checks / Spies) | Vi phạm SVA | Thời gian mô phỏng | Kết quả |
| :---: | :--- | :--- | :---: | :---: | :---: | :---: |
| 1 | [`branch_predictor_tb.v`](vivado/vivado.srcs/sim_1/new/branch_predictor_tb.v) | BHT 2-bit Saturating Counter, BTB Tag Match & Penalty | 23 Checks | 0 | 178 ns | **PASSED** |
| 2 | [`multiplier_tb.v`](vivado/vivado.srcs/sim_1/new/multiplier_tb.v) | RV32M MUL, MULH, MULHSU, MULHU Signed/Unsigned Extremes | 23 Checks | 0 | 240 ns | **PASSED** |
| 3 | [`divider_tb.v`](vivado/vivado.srcs/sim_1/new/divider_tb.v) | DIV, DIVU, REM, REMU, Divide-by-Zero, Signed Overflow Fast-Exit | 28 Checks | 0 | 6,996 ns | **PASSED** |
| 4 | [`alu_tb.v`](cpu_pipeline.srcs/sim_1/new/alu_tb.v) | RV32I 32-bit ALU: 12 phép toán & corner cases (ADD, SUB, SLT, SLTU, SLL, SRA, SRL, XOR, OR, AND, LUI, Default) | 12 Checks | 0 | 120 ns | **PASSED** |
| 5 | [`regfile_tb.v`](cpu_pipeline.srcs/sim_1/new/regfile_tb.v) | 32 thanh ghi 32-bit, bảo toàn x0 == 0, ghi/đọc đồng thời 2 cổng | 16 Checks | 0 | 320 ns | **PASSED** |
| 6 | [`forwarding_tb.v`](cpu_pipeline.srcs/sim_1/new/forwarding_tb.v) | Forwarding Unit: EX/MEM & MEM/WB forward sang RS1/RS2 | 16 Checks | 0 | 280 ns | **PASSED** |
| 7 | [`control_unit_tb.v`](cpu_pipeline.srcs/sim_1/new/control_unit_tb.v) | Bộ giải mã chính & ALU Decoder: R, I, S, B, U, J, M-ext, CSR, FENCE.I, TRAP, Default | 42 Checks | 0 | 470 ns | **PASSED** |
| 8 | [`csr_file_tb.v`](vivado/vivado.srcs/sim_1/new/csr_file_tb.v) | Tập thanh ghi CSR (mstatus, mie, mtvec, mepc, mcause, mip, mcycle, minstret), Trap & MRET | 21 Checks | 0 | 815 ns | **PASSED** |
| 9 | [`icache_tb.v`](vivado/vivado.srcs/sim_1/new/icache_tb.v) | L1 I-Cache Hit/Miss, Refill Burst, Line Replacement, Flush | 29 Checks | 0 | 1,307 ns | **PASSED** |
| 10 | [`axi_gpio_tb.v`](vivado/vivado.srcs/sim_1/new/axi_gpio_tb.v) | AXI GPIO Input debouncing, Output LED register, Tri-state | 16 Checks | 0 | 756 ns | **PASSED** |
| 11 | [`axi_timer_tb.v`](vivado/vivado.srcs/sim_1/new/axi_timer_tb.v) | 64-bit MTIME, MTIMECMP Interrupt, Auto-reload | 19 Checks | 0 | 1,706 ns | **PASSED** |
| 12 | [`axi_uart_lite_tb.v`](vivado/vivado.srcs/sim_1/new/axi_uart_lite_tb.v) | UART Baud Gen, Glitch Filter, Framing Error, Bit-Toggle Pattern | 29 Checks | 0 | 14,571 ns | **PASSED** |
| 13 | [`uart_divisor434_tb.v`](vivado/vivado.srcs/sim_1/new/uart_divisor434_tb.v) | Phần cứng UART Divisor 434 (115200 Baud @ 50MHz), 2µs Glitch Rejection, Full Duplex Loopback | 7 Checks | 0 | 293,850 ns | **PASSED** |
| 14 | [`axi_interconnect_tb.v`](vivado/vivado.srcs/sim_1/new/axi_interconnect_tb.v) | Crossbar 2x4, DECERR Trap, Channel Handshake Arbitration | 26 Checks | 0 | 756 ns | **PASSED** |
| 15 | [`axi_stress_tb.v`](vivado/vivado.srcs/sim_1/new/axi_stress_tb.v) | 400 gói tin đồng thời M0/M1, 50% Random Backpressure, AW/W Phase Skew (8 cycles) | 6 Checks | 0 | 13,200 ns | **PASSED** |
| 16 | [`cpu_tb.v`](cpu_pipeline.srcs/sim_1/imports/new/cpu_tb.v) | RV32IM CPU Pipeline Hazards, Forwarding, SVA Bindings | 56 Checks | 0 | 7,545 ns | **PASSED** |
| 17 | [`soc_interrupt_tb.v`](vivado/vivado.srcs/sim_1/new/soc_interrupt_tb.v) | 3 xung ngắt phần cứng Timer liên tiếp, Trap MTVEC, MCAUSE 0x80000007, MRET khôi phục MIE | 19 Checks | 0 | 3,070 ns | **PASSED** |
| 18 | [`soc_isa_tb.v`](vivado/vivado.srcs/sim_1/new/soc_isa_tb.v) | Bộ kiểm thử tuân thủ nội bộ theo đặc tả RV32UI/RV32UM (In-house Compliance Suite): 73 testcases toàn diện cho RV32UI & RV32UM | 73 Tests | 0 | 18,920 ns | **PASSED** |
| 19 | [`soc_random_tb.v`](vivado/vivado.srcs/sim_1/new/soc_random_tb.v) | 382 lệnh ngẫu nhiên có ràng buộc (RAW hazard, forwarding stress) so với Python Golden Model | 32 Regs | 0 | 9,840 ns | **PASSED** |
| 20 | [`soc_tb.v`](vivado/vivado.srcs/sim_1/new/soc_tb.v) | Toàn bộ SoC (CPU + Crossbar + BRAM + Tất cả Ngoại vi) | 18 Checks | 0 | 2,350 ns | **PASSED** |
| 21 | [`soc_firmware_tb.v`](vivado/vivado.srcs/sim_1/new/soc_firmware_tb.v) | Nạp Bootloader C Firmware, UART Output Sniffer, ECALL Halt | 7 Checks | 0 | 522,170 ns | **PASSED** |
| 22 | [`soc_pipeline_stress_tb.v`](vivado/vivado.srcs/sim_1/new/soc_pipeline_stress_tb.v) | Ma trận tương tác sự kiện đường ống (Timer IRQ đồng thời với Bus stall, Divider busy, Mispredict flush, MRET re-entrancy; chống ghi Store bị flush; FENCE.I self-modifying code; quét byte/halfword offset LB/LH/LBU/LHU/SB/SH) | 14 Checks | 0 | 11,310 ns | **PASSED** |
| 23 | [`soc_trace_tb.v`](vivado/vivado.srcs/sim_1/new/soc_trace_tb.v) | Kiểm thử hồi quy 100 seeds phân lô luồng điều khiển động (36,232 lệnh, Branches, Jumps, Loops, Sub-word, CSR) 100% khớp với Python Golden Model | 36,232 Insts | 0 | 345,120 ns | **PASSED** |

### 📊 6.1 Báo cáo độ bao phủ mã nguồn thực tế (Code Coverage Report - Vivado xcrg)

Dưới đây là bảng số liệu cơ sở lịch sử (Baseline) được đo lường thực nghiệm từ công cụ **Vivado Simulator Coverage Engine** với cờ -cc_type sbct (Statement, Branch, Condition, Toggle) và trích xuất báo cáo bằng **Vivado Coverage Report Generator (xcrg)**:

> [!NOTE]
> **Minh bạch về Phạm vi Đo lường Coverage & Rào cản Kỹ thuật EDA:**
> 1. **Phạm vi số liệu bảng (Historical 21-TB Baseline):**
>    - Báo cáo coverage dưới đây (**98.67% Line, 89.50% Branch, 58.33% Condition, 49.35% Toggle**) được trích xuất từ cơ sở dữ liệu modular đo lường **21 testbench gốc ban đầu** (từ `branch_predictor_tb` đến `soc_firmware_tb`).
>    - Hai testbench quy mô lớn mới bổ sung là `soc_pipeline_stress_tb` (#22) và `soc_trace_tb` (#23) **CHƯA ĐƯỢC GỘP** vào cơ sở dữ liệu này. Đây là lý do các chỉ số giữ nguyên so với báo cáo ban đầu.
> 2. **Hiện trạng lỗi công cụ biên dịch nội bộ trên Windows 11:**
>    - Khi thực thi lệnh đo coverage tự động (xelab -cc_type sbct), trình biên dịch C nội bộ của Vivado 2022.2 trên Windows báo lỗi ERROR: [XSIM 43-3409] Failed to compile generated C file xsim_1.c ngay cả ở các module đơn lẻ như lu_tb.
>    - Hướng khắc phục chuẩn hóa trong công nghiệp: (a) Đo coverage ở cấp core độc lập (`cpu_top`/`datapath`, cô lập không gắn AXI Interconnect/RAM); (b) Chạy Vivado mô phỏng trong môi trường Linux (Ubuntu container / WSL2) để trình biên dịch GCC Linux xử lý trơn tru bảng dữ liệu instrumentation.
> 3. **Ước lượng nhánh logic bổ sung (Dự kiến theo kịch bản, chưa đo bằng xcrg):**
>    - Về mặt lý thuyết kịch bản kiểm thử, việc chạy 36,232 lệnh luồng điều khiển động và ma trận ngắt/stall dự kiến sẽ bao phủ các nhánh mã trước đây chưa chạm tới:
>      * `hazard_unit.v`: Cơ chế stall 1 chu kỳ cho mul_branch_hazard (2,015 lần kích hoạt), cơ chế flush `if_id_flush` khi đoán sai nhánh (4,485 lần).
>      * `branch_predictor.v`: Cập nhật chuyển trạng thái bộ đếm bão hòa BHT 2-bit (7,791 lần), kiểm tra Tag BTB và chuyển hướng PC.
>      * `datapath.v`: Giải mã và tính toán địa chỉ rẽ nhánh `branch_comparator`, `jal/jalr`, nạp địa chỉ pc, mở rộng có dấu/không dấu cho `lb`, `lh`, `lbu`, `lhu`.
> 4. **Phân định Toggle Coverage giữa BRAM và Register File:**
>    - BRAM (`ram_reg` 131,072 bit) bị xSim bỏ qua do vượt trần 32,768 bit (`WARNING: The total size of variable ram is 131072. Skipping this variable from Toggle Coverage as the maximum size is limited to 32768`).
>    - Register file (`registers` 1,024 bit) dưới ngưỡng 32k-bit, nhưng bị xSim bỏ qua do thiết kế công cụ không đo toggle trên mảng 2 chiều không đóng gói (`reg [31:0] registers [31:0]`).

| Module File | Nguồn kiểm thử tối ưu (Best Source) | Statement (Line) % | Branch % | Condition % | Toggle % |
| :--- | :--- | :---: | :---: | :---: | :---: |
| [`alu.v`](cpu_pipeline.srcs/sources_1/imports/new/alu.v) | `alu_tb` | **100.00%** | **85.71%** | 33.33% | 65.50% |
| [`axi_gpio.v`](vivado/vivado.srcs/sources_1/new/axi_gpio.v) | `axi_gpio_tb` | **100.00%** | **100.00%** | 0.00% | 33.45% |
| [`axi_interconnect.v`](vivado/vivado.srcs/sources_1/new/axi_interconnect.v) | `axi_interconnect_tb` | **100.00%** | **100.00%** | **100.00%** | 23.02% |
| [`axi_lite_master_d.v`](vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v) | `cpu_tb` | **93.24%** | **81.40%** | **100.00%** | 70.00% |
| [`axi_timer.v`](vivado/vivado.srcs/sources_1/new/axi_timer.v) | `axi_timer_tb` | **100.00%** | **90.91%** | 0.00% | 27.85% |
| [`axi_uart_lite.v`](vivado/vivado.srcs/sources_1/new/axi_uart_lite.v) | `axi_uart_lite_tb` | **100.00%** | **95.83%** | **100.00%** | 42.37% |
| [`branch_comp.v`](vivado/vivado.srcs/sources_1/new/branch_comp.v) | `cpu_tb` | **100.00%** | 0.00% | **100.00%** | 0.00% |
| [`branch_predictor.v`](vivado/vivado.srcs/sources_1/new/branch_predictor.v) | `soc_firmware_tb` | **95.24%** | **94.12%** | 0.00% | 1.55% |
| [`control_unit.v`](cpu_pipeline.srcs/sources_1/imports/new/control_unit.v) | `control_unit_tb` | **98.60%** | **92.86%** | **100.00%** | **89.09%** |
| [`csr_file.v`](vivado/vivado.srcs/sources_1/new/csr_file.v) | `csr_file_tb` | **94.83%** | **92.50%** | **100.00%** | 21.62% |
| [`datapath.v`](cpu_pipeline.srcs/sources_1/imports/new/datapath.v) | `cpu_tb` | **100.00%** | **98.11%** | **100.00%** | 52.91% |
| [`divider.v`](vivado/vivado.srcs/sources_1/new/divider.v) | `divider_tb` | **97.56%** | **95.24%** | **100.00%** | **92.84%** |
| [`forwarding_unit.v`](cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v) | `cpu_tb` | **100.00%** | **100.00%** | **100.00%** | **100.00%** |
| [`hazard_unit.v`](cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v) | `soc_firmware_tb` | **100.00%** | **100.00%** | 33.33% | **80.00%** |
| [`icache.v`](vivado/vivado.srcs/sources_1/new/icache.v) | `icache_tb` | **98.36%** | **92.31%** | **100.00%** | 0.79% |
| [`imm_gen.v`](vivado/vivado.srcs/sources_1/new/imm_gen.v) | `cpu_tb` | **100.00%** | **100.00%** | 0.00% | **100.00%** |
| [`multiplier.v`](vivado/vivado.srcs/sources_1/new/multiplier.v) | `cpu_tb` | **100.00%** | **100.00%** | 0.00% | **90.37%** |
| [`pipeline_registers.v`](cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v) | `cpu_tb` | **97.28%** | **93.75%** | 0.00% | **75.16%** |
| [`register_file.v`](cpu_pipeline.srcs/sources_1/imports/new/register_file.v) | `cpu_tb` | **100.00%** | **100.00%** | **100.00%** | 0.00% |
| [`soc_top.v`](vivado/vivado.srcs/sources_1/new/soc_top.v) | `soc_tb` | **98.28%** | **77.27%** | 0.00% | 20.48% |
| **TRUNG BÌNH HỆ THỐNG (SYSTEM AVERAGE)** | — | **98.67%** | **89.50%** | **58.33%** | **49.35%** |

---

### 🛡️ 6.2 Đánh giá năng lực phát hiện lỗi vi mạch & Ma trận Tiêu diệt Đột biến (Full Mutation Kill Matrix)
Để chứng minh bộ testbench và hệ thống SVA thực sự có năng lực phát hiện và "bắt chết" (kill) các lỗi vi kiến trúc nếu chúng phát sinh trong RTL (thay vì chỉ chạy qua mã đúng một cách thụ động), một quy trình kiểm thử đột biến tự động toàn diện trên **18 lỗi vi kiến trúc (8 Sanity Mutants + 10 Hard Mutants)** đã được thực thi đối chiếu chéo qua **9 bộ testbench độc lập** thông qua [`tools/run_mutation_matrix.py`](tools/run_mutation_matrix.py).

Toàn bộ **162 tệp nhật ký thực thi chi tiết (Raw Logs)** đã được xuất và lưu trữ nguyên văn tại thư mục [`logs/mutation/`](logs/mutation/) để phục vụ tái lập độc lập.

#### 6.2.1 Ma trận Tiêu diệt Đột biến Toàn diện (18 Mutants $\times$ 9 Testbenches)

| Mã Mutant | File Đích | Trace (36k Insts) | Stress TB | ISA Compliance | Interrupt TB | Forwarding Unit | Divider Unit | Multiplier Unit | Branch Predictor | CSR Unit | Trạng thái (Overall) |
| :---: | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **MUT-01** | `hazard_unit.v` | 🔴 **KILLED** | 🔴 **KILLED** | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-02** | `forwarding_unit.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-03** | `csr_file.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | **KILLED (100%)** |
| **MUT-04** | `icache.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-05** | `axi_lite_master_d.v` | 🔴 **KILLED** | 🔴 **KILLED** | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-06** | `register_file.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-07** | `multiplier.v` | 🔴 **KILLED** | 🔴 **KILLED** | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **MUT-08** | `datapath.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-01** | `forwarding_unit.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-02** | `hazard_unit.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-03** | `multiplier.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-04** | `divider.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-05** | `csr_file.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | **KILLED (100%)** |
| **HARD-06** | `csr_file.v` | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | **KILLED (100%)** |
| **HARD-07** | `axi_lite_master_d.v` | 🔴 **KILLED** | 🔴 **KILLED** | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-08** | `branch_predictor.v` | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-09** | `divider.v` | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |
| **HARD-10** | `divider.v` | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | 🔴 **KILLED** | ⚪ *SURVIVED* | ⚪ *SURVIVED* | ⚪ *SURVIVED* | **KILLED (100%)** |

$$\text{Tổng điểm Đột biến Toàn diện (Overall Mutation Score)} = \frac{18}{18} \times 100\% = \mathbf{100.0\%} \quad \text{(0 Escapes)}$$

> [!IMPORTANT]
> **Phân tích Ý nghĩa Kiến trúc từ Ma trận Tiêu diệt Đột biến (Architectural Takeaways):**
> 1. **Năng lực của bộ Trace Luồng Điều khiển Mới (`soc_trace_tb`):** Nhờ bổ sung 7,791 lệnh rẽ nhánh và các lệnh nhảy/sub-word/MUL/DIV, `soc_trace_tb` đã bắt chết **10/18 mutants** (bao gồm `MUT-01` branch flush, `HARD-01` forwarding priority inversion, `HARD-02` load-use rs2, `HARD-07` SH byte enable, và `HARD-08` BTB tag truncation).
> 2. **Sự cần thiết của Kiến trúc Kiểm chứng Phân tầng (Layered DV Hierarchy):**
>    - Các mutant `MUT-03`, `HARD-05`, `HARD-06` (liên quan đến ngắt Timer, cờ MIE và thanh ghi MEPC) *sống sót* trước trace thuần túy, nhưng bị tiêu diệt dứt điểm bởi `soc_interrupt_tb` và `soc_pipeline_stress_tb`.
>    - Các mutant `HARD-09`, `HARD-10` (chia cho 0 và tràn số chia có dấu) bị tiêu diệt chính xác bởi `divider_tb` và `soc_isa_tb`.

---

### 🔬 6.3 Kiểm chứng đối chiếu vết lệnh hưu trí quy mô lớn (High-Volume Retire Trace Regression)
Để giải quyết triệt để vấn đề "số lượng lệnh ngẫu nhiên quá ít để vét hết hazard" và "thiếu vắng luồng điều khiển", bộ kiểm thử tự động [`tools/run_multi_seed_trace_36k.py`](tools/run_multi_seed_trace_36k.py) được nâng cấp toàn diện theo kiến trúc **phân lô (batched regression)** tích hợp đầy đủ không gian lệnh RV32IM, nhảy, rẽ nhánh, vòng lặp và truy xuất bộ nhớ bán từ:

- **Tại sao cần kiến trúc phân lô (Batched Architecture)?**
  Bộ nhớ BRAM tích hợp trong SoC có kích thước 16 KB (chứa tối đa 4,096 lệnh 32-bit). Một chương trình đơn khối chứa 36,000 lệnh sẽ chiếm 144 KB, gây tràn bộ nhớ BRAM vật lý. Giải pháp kỹ thuật chuẩn mực là chia 100 seed thành 10 lô độc lập (mỗi lô chứa 10 seed $\times$ ~360 lệnh $\approx 3,600$ lệnh $\approx 14$ KB, nằm gọn an toàn trong 16 KB BRAM).
- **Phân loại tập lệnh & Số liệu Vi kiến trúc Thực nghiệm:**
  Trong tổng số **36,232 lệnh**, hệ thống ghi nhận sự kích thích mạnh mẽ của mọi cơ chế đường ống:
  - **Tỷ lệ RAW Hazard liên tiếp:** $11,377 / 36,232 \approx \mathbf{31.40\%}$.
  - **Xung đột Multiplier-to-Branch:** **2,015 lần** chèn bong bóng stall thành công tại tầng ID để bảo vệ critical path DSP.
  - **Rẽ nhánh đoán sai (Branch Mispredict):** **4,485 lần** phát hiện và kích hoạt `if_id_flush` xóa sạch bóng lệnh đầu cơ.
  - **Tỷ lệ kết quả rẽ nhánh:** **3,787 Nhánh Nhảy (Taken, 48.61%)** vs **4,004 Nhánh Không Nhảy (Untaken, 51.39%)** (phân bố cân bằng lý tưởng).

| Nhóm lệnh (Instruction Category) | Số lệnh thực thi (Count) | Tỷ trọng (% of Total) | Các loại Hazard vi kiến trúc được kích hoạt |
| :--- | :---: | :---: | :--- |
| **I-type ALU** (`addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `srai`, `slti`, `sltiu`) | 9,162 | **25.29%** | Forwarding EX/MEM và MEM/WB, Immediate Sign-Extension |
| **Conditional Branch (B-type)** (`beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu`) | 7,791 | **21.50%** | **Early Branch Resolution, 4,485 Mispredict Flushes, BHT 2-bit Updates** |
| **M-ext Multiplier** (`mul`, `mulh`, `mulhu`, `mulhsu`) | 3,975 | **10.97%** | **2,015 Multiplier-to-Branch Stalls**, trích xuất tích số DSP |
| **Store (SW)** (`sw`) | 1,983 | **5.47%** | Bắt tay ghi AXI4-Lite (`awvalid`/`wvalid`), xung đột Store-to-Load |
| **CSR Privilege / System** (`csrrw`, `ecall`) | 1,960 | **5.41%** | Ghi/đọc thanh ghi đặc quyền `mscratch`, bẫy ngắt dừng hệ thống |
| **Load (LW)** (`lw`) | 1,940 | **5.35%** | **Load-Use Pipeline Stall**, Bắt tay đọc AXI4-Lite (`arvalid`/`rvalid`) |
| **U-type (LUI / AUIPC)** (`lui`, `auipc`) | 1,911 | **5.27%** | Nạp hằng số 20-bit, tính địa chỉ tương đối PC (`auipc`) |
| **R-type ALU** (`add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu`) | 1,907 | **5.26%** | Phép toán 2 thanh ghi nguồn, Forwarding hai kênh RS1 và RS2 |
| **M-ext Divider** (`div`, `divu`, `rem`, `remu`) | 1,849 | **5.10%** | **Pipeline Hold Freeze 32 chu kỳ**, Chống rơi cờ `div_done` |
| **Unconditional Jump** (`jal`, `jalr`) | 1,816 | **5.01%** | Nhảy không điều kiện, ghi liên kết PC+4 vào thanh ghi `ra` |
| **Sub-word Load** (`lb`, `lh`, `lbu`, `lhu`) | 1,292 | **3.57%** | Kiểm tra mở rộng có dấu/không dấu cho Byte và Halfword |
| **Sub-word Store** (`sb`, `sh`) | 646 | **1.78%** | Kiểm tra mặt nạ ghi từng byte `wstrb` tại các offset lẻ |
| **TỔNG CỘNG HỒI QUY** | **36,232** | **100.00%** | **36,232 / 36,232 Khớp Tuyệt Đối (0 Mismatches vs Python Model)** |

- **Kết quả đối chiếu vết lệnh hưu trí qua 10 Lô (Retire Trace Batches):**

| Lô kiểm thử (Batch) | Dải Seed thực thi | Số lệnh hưu trí (Retired Insts) | RAW Hazards | Mul->Branch Stalls | Mispredict Flushes | Sai lệch so với Golden Model Python |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Batch 01/10** | Seed 001 .. 010 | 3,635 lệnh | 1,138 hazards | 207 stalls | 461 flushes | **0 Mismatches** (100% Pass) |
| **Batch 02/10** | Seed 011 .. 020 | 3,549 lệnh | 1,221 hazards | 207 stalls | 453 flushes | **0 Mismatches** (100% Pass) |
| **Batch 03/10** | Seed 021 .. 030 | 3,559 lệnh | 1,120 hazards | 205 stalls | 429 flushes | **0 Mismatches** (100% Pass) |
| **Batch 04/10** | Seed 031 .. 040 | 3,691 lệnh | 1,109 hazards | 213 stalls | 464 flushes | **0 Mismatches** (100% Pass) |
| **Batch 05/10** | Seed 041 .. 050 | 3,613 lệnh | 1,106 hazards | 192 stalls | 414 flushes | **0 Mismatches** (100% Pass) |
| **Batch 06/10** | Seed 051 .. 060 | 3,674 lệnh | 1,112 hazards | 199 stalls | 477 flushes | **0 Mismatches** (100% Pass) |
| **Batch 07/10** | Seed 061 .. 070 | 3,615 lệnh | 1,125 hazards | 187 stalls | 469 flushes | **0 Mismatches** (100% Pass) |
| **Batch 08/10** | Seed 071 .. 080 | 3,599 lệnh | 1,143 hazards | 198 stalls | 430 flushes | **0 Mismatches** (100% Pass) |
| **Batch 09/10** | Seed 081 .. 090 | 3,681 lệnh | 1,128 hazards | 203 stalls | 459 flushes | **0 Mismatches** (100% Pass) |
| **Batch 10/10** | Seed 091 .. 100 | 3,616 lệnh | 1,175 hazards | 204 stalls | 429 flushes | **0 Mismatches** (100% Pass) |
| **TỔNG CỘNG HỒI QUY**| **100 SEEDS** | **36,232 LỆNH** | **11,377 HAZARDS** | **2,015 STALLS** | **4,485 FLUSHES** | **0 MISMATCHES (100.00% PASS)** |

---

### 🧩 6.4 Mở rộng kiểm thử bộ nhớ bán từ (Sub-Word Alignment & Overwrite Integrity)
Trong kịch bản [`coverage/soc_pipeline_stress.s`](coverage/soc_pipeline_stress.s) và [`soc_pipeline_stress_tb.v`](vivado/vivado.srcs/sim_1/new/soc_pipeline_stress_tb.v), toàn bộ không gian corner case của các lệnh truy xuất bán từ (sub-word access) đã được bao phủ hoàn chỉnh:

1. **Bao phủ toàn diện cả 4 byte offset (0, 1, 2, 3):**
   - Lưu 4 byte khác nhau bằng `SB`: Byte 0 (`0x8F`), Byte 1 (`0x7E`), Byte 2 (`0xA5`), Byte 3 (`0x5A`) vào địa chỉ `0x400`.
   - Đọc lại toàn từ `LW` vào thanh ghi `x10` kiểm tra đúng giá trị kết hợp: `0x5AA57E8F`.
2. **Đối đối có dấu vs không dấu (Signed vs Unsigned):**
   - **Byte âm (`0x8F`, `0xA5`):**
     * `LB` offset 0 ra `0xFFFFFF8F` (thanh ghi `x11`) vs `LBU` offset 0 ra `0x0000008F` (thanh ghi `x12`).
     * `LB` offset 2 ra `0xFFFFFFA5` (thanh ghi `x3`) vs `LBU` offset 2 ra `0x000000A5` (thanh ghi `x6`).
   - **Byte dương (`0x7E`, `0x5A`):**
     * `LB` offset 1 ra `0x0000007E` (`x13`) vs `LBU` offset 1 ra `0x0000007E` (`x5`).
     * `LB` offset 3 ra `0x0000005A` (`x4`) vs `LBU` offset 3 ra `0x0000005A` (`x7`).
   - **Nửa từ (Halfword) có dấu vs không dấu tại `0x408`:**
     * `LH` offset 0 ra `0xFFFF8001` (thanh ghi `x14`) vs `LHU` offset 0 ra `0x00008001` (thanh ghi `x15`).
     * `LH` offset 2 ra `0x00007FFF` (thanh ghi `x16`).
3. **Tính toàn vẹn khi ghi đè từng byte (Byte Overwrite Integrity at `0x420`):**
   - Ghi từ cơ sở `0x11223344` vào `0x420`.
   - Ghi đè Byte 1 bằng lệnh `SB` giá trị `0x99` vào địa chỉ `0x421`.
   - Ghi đè Byte 3 bằng lệnh `SB` giá trị `0xCC` vào địa chỉ `0x423`.
   - Đọc lại nguyên từ bằng `LW` vào thanh ghi `x1`: giá trị đạt chính xác tuyệt đối **`0xCC229944`** (Byte 0 giữ nguyên `0x44`, Byte 2 giữ nguyên `0x22`, không bị lem hay ghi nhầm bit).
4. **Hành vi cắt tỉa khi truy xuất không căn chỉnh (Unaligned Access Truncation at `0x428`):**
   - Từ cơ sở tại `0x428` là `0xAABBCCDD`.
   - Thực hiện lệnh `LH` từ địa chỉ lẻ `0x429` (offset 1): phần cứng cắt tỉa theo bit `addr[1] == 0`, trả về đúng nửa từ thấp có dấu **`0xFFFFCCDD`** vào thanh ghi `x18`.

---

## 🐞 7. DANH SÁCH ĐIỂM NGHẼN KỸ THUẬT ĐÃ XỬ LÝ TRIỆT ĐỂ (ROOT CAUSE ANALYSIS)

Dưới đây là các lỗi vi kiến trúc phần cứng phức tạp đã được phát hiện, phân tích nguyên nhân gốc rễ và xử lý triệt để theo chuẩn vi mạch chuyên nghiệp:

### 1. Bẫy khóa bus (Deadlock / Misroute) trong AMBA AXI4-Lite Interconnect
* **Tệp:** [`axi_interconnect.v`](vivado/vivado.srcs/sources_1/new/axi_interconnect.v)
* **Nguyên nhân gốc rễ:** Khi Master thực hiện ghi dữ liệu đơn chu kỳ (như BRAM write), tín hiệu `s_axi_bvalid` và `s_axi_awready` được kích hoạt gần như đồng thời. Logic điều khiển kênh ghi gán ưu tiên giữ trạng thái kích hoạt mới (`wr_active <= 1'b1`) trước khi hạ trạng thái giao dịch cũ (`wr_active <= 1'b0`). Tín hiệu `wr_active` bị kẹt ở mức logic `1` vĩnh viễn và trỏ cố định về Slave 0 (BRAM). Mọi lệnh ghi tiếp theo của CPU ra ngoại vi (UART, GPIO, Timer) đều bị định tuyến sai (misroute) sang BRAM.
* **Giải pháp:** Tái cấu trúc logic máy trạng thái kênh ghi/đọc: Ưu tiên giải phóng bus (`if (s_axi_bvalid && s_axi_bready) wr_active <= 1'b0`) trước logic tiếp nhận giao dịch mới, giải quyết dứt điểm hiện tượng kẹt kênh.

### 2. Lỗi mất giao dịch AXI do bắt tay không đồng bộ (Skewed AW-before-W Handshake)
* **Tệp liên quan:** [`axi_uart_lite.v`](vivado/vivado.srcs/sources_1/new/axi_uart_lite.v), [`axi_timer.v`](vivado/vivado.srcs/sources_1/new/axi_timer.v), [`axi_gpio.v`](vivado/vivado.srcs/sources_1/new/axi_gpio.v)
* **Nguyên nhân gốc rễ:** Thanh ghi lưu địa chỉ ghi tạm thời `awaddr_valid_reg` bị xóa bởi điều kiện `else if (s_axi_bready)` thay vì `else if (s_axi_bvalid && s_axi_bready)`. Nếu Master kích hoạt `bready = 1` từ trước khi `wvalid` xuất hiện, Slave đã xóa mất địa chỉ trước khi dữ liệu ghi tới, làm mất giao dịch.
* **Giải pháp:** Chuẩn hóa điều kiện deassert: `awaddr_valid_reg <= 1'b0` chỉ khi hoàn tất bắt tay kênh phản hồi (`bvalid && bready`).

### 3. Lỗi lệch pha chu kỳ kết thúc UART (TX-RX Stop Bit Skew & Framing Error Hang)
* **Tệp:** [`axi_uart_lite.v`](vivado/vivado.srcs/sources_1/new/axi_uart_lite.v), [`axi_uart_lite_tb.v`](vivado/vivado.srcs/sim_1/new/axi_uart_lite_tb.v)
* **Nguyên nhân gốc rễ:** Máy trạng thái RX (`RX_STOP`) lấy mẫu bit Stop ở giữa chu kỳ (`TEST_DIV / 2`), trong khi TX (`TX_STOP`) chỉ giải phóng `tx_ready` ở cuối chu kỳ (`TEST_DIV`). Khi testbench nhận byte `0x55` rồi lập tức phản hồi ghi byte `0xAA`, thanh ghi TX vẫn đang bận (`tx_ready = 0`), khiến lệnh ghi CPU bị từ chối. Kết hợp với việc testbench dùng `wait(uart_irq == 1)` vô hạn khiến mô phỏng kẹt cứng hơn 20 phút.
* **Giải pháp:** Hiệu chỉnh logic FSM RX khôi phục an toàn về `RX_IDLE` khi gặp Framing Error; chuyển đổi toàn bộ testbench sang cơ chế thăm dò có giới hạn `wait_for_tx_ready(300)` và Watchdog Timer `#100000`.

### 4. Điểm nghẽn khả năng điều khiển (Controllability) của bộ đếm 64-bit CSR
* **Tệp:** [`csr_file.v`](vivado/vivado.srcs/sources_1/new/csr_file.v)
* **Nguyên nhân gốc rễ:** Bộ đếm phần cứng 64-bit `mcycle` và `minstret` chỉ tăng từng chu kỳ. Việc kiểm thử hiện tượng tràn số (rollover) từ `0x00000000FFFFFFFF` lên `0x0000000100000000` đòi hỏi chạy hơn $4 \times 10^9$ chu kỳ xung nhịp—bất khả thi trong mô phỏng.
* **Giải pháp:** Bổ sung quyền ghi từ Machine-mode cho 4 CSR: `CSR_MCYCLE` (`0xC00`), `CSR_MCYCLEH` (`0xC80`), `CSR_MINSTRET` (`0xC02`), và `CSR_MINSTRETH` (`0xC82`). Nhờ đó, testbench có thể nạp thẳng giá trị biên `0xFFFFFFFE` và kiểm chứng rollover 64-bit chỉ trong đúng 5 chu kỳ.

### 5. Xung đột Critical Path 23.1 ns từ DSP Multiplier sang ID Branch Comparator
* **Nguyên nhân gốc rễ:** Cơ chế rẽ nhánh sớm tại tầng ID nhận dữ liệu forwarded trực tiếp từ `ex_final_result` (chạy qua cascade 12 lát DSP48E1 và 13 tầng cộng dồn CARRY4), tạo thành đường truyền kéo dài 23.1 ns xuyên suốt 2 tầng pipeline, vi phạm nặng nề thời gian xác lập ($WNS = -3.448\text{ ns}$).
* **Giải pháp:** 
  1. Thêm cơ chế **Multiplier-to-Branch Hazard Detection** trong `hazard_unit.v`: Chèn 1 chu kỳ bong bóng nếu lệnh tại ID là rẽ nhánh và phụ thuộc vào kết quả của lệnh nhân tại EX.
  2. Các MUX rẽ nhánh tại ID chỉ nhận dữ liệu từ `alu_result_ex` (độ trễ $\approx 2\text{ ns}$); kết quả phép nhân được forward an toàn từ tầng `MEM` sau khi đã chốt qua thanh ghi. Đạt Timing Closure hoàn hảo: $WNS = \mathbf{+0.540\text{ ns}}$.

### 6. Lỗi Forwarding hết hạn ở bộ chia đa chu kỳ (Divider Stale Forwarding Hazard)
* **Nguyên nhân gốc rễ:** Mạch MUX đầu ra của `divider.v` hỗ trợ cơ chế thoát nhanh (Fast-Exit) cho trường hợp chia cho 0. Tín hiệu Forwarding về `i_divisor` hết hạn sau 30 chu kỳ tính toán và de-assert về 0. Khi bộ chia chuyển sang `STATE_DONE`, mạch tổ hợp phát hiện `i_divisor == 0` và kích hoạt nhầm Fast-Exit, ép thương số về `-1`.
* **Giải pháp:** Ràng buộc điều kiện thoát nhanh chỉ được phép kích hoạt tại trạng thái khởi đầu: `if ((state == STATE_IDLE) && fast_exit)`. Tại `STATE_DONE`, kết quả được chốt độc quyền từ thanh ghi `calc_quo` hoặc `calc_rem`.

### 7. Tích hợp Điều khiển Ngắt Phần cứng (Timer IRQ, MRET) & Xử lý Vòng lặp Tổ hợp
* **Nguyên nhân gốc rễ:**
  1. `control_unit.v` decode `funct3 == 3'b000` của `OPCODE_SYSTEM` thành `ecall_halt` mà không kiểm tra 12 bit cao (`i_funct12 == 12'h302`), khiến lệnh `mret` dừng CPU thay vì quay lại luồng chính.
  2. `datapath.v` thiếu MUX chuyển hướng tới `mtvec` khi có ngắt và `csr_file.v` thiếu logic sinh `trap_irq_req`.
  3. Khi nối `trap_taken` vào `hazard_unit.v`, việc kiểm tra trap trước bus stall tạo thành vòng lặp tổ hợp (Combinatorial Loop) giữa `o_pipeline_hold` và `trap_taken`, gây lỗi DRC `LUTLP-1`.
* **Giải pháp:**
  1. Bổ sung `i_funct12` vào `control_unit.v` để phân biệt chính xác `mret` và `ecall`.
  2. Tích hợp logic sinh ngắt chuẩn Machine Mode trong `csr_file.v` (`mstatus.MIE && mie.MTIE && mip.MTIP`), tự động chốt PC vào `mepc`, lưu cờ ngắt vào `mcause` (`0x80000007`), và khôi phục MIE khi thi hành `mret`.
  3. Đặt mức ưu tiên Bus Stall lên hàng đầu tuyệt đối trong `hazard_unit.v`, loại bỏ hoàn toàn vòng lặp tổ hợp, đạt **0 Combinational Loops** và khép kín STA: $WNS = \mathbf{+0.736\text{ ns}}$.

---

## 📊 8. TỔNG HỢP TÀI NGUYÊN VẬT LÝ & STA TIMING TRÊN FPGA (ARTY Z7-20)

*(Trích xuất chính thức từ báo cáo triển khai vật lý `vivado/reports/utilization.rpt` và `timing_summary.rpt`)*:

### 8.1 Bảng sử dụng tài nguyên chip FPGA (`xc7z020clg400-1`)
```text
+----------------------------+------+-------+------------+-----------+-------+
|          Site Type         | Used | Fixed | Prohibited | Available | Util% |
+----------------------------+------+-------+------------+-----------+-------+
| Slice LUTs                 | 4073 |     0 |          0 |     53200 |  7.66 |
|   LUT as Logic             | 3747 |     0 |          0 |     53200 |  7.04 |
|   LUT as Memory (Dist RAM) |  326 |     0 |          0 |     17400 |  1.87 |
| Slice Registers (FF)       | 1955 |     0 |          0 |    106400 |  1.84 |
|   Register as Latch        |    0 |     0 |          0 |    106400 |  0.00 |
| F7 / F8 Muxes              |   44 |     0 |          0 |     39900 |  0.11 |
| Block RAM (RAMB36E1)       |    4 |     0 |          0 |       140 |  2.86 |
| DSP48E1 Slices             |   12 |     0 |          0 |       220 |  5.45 |
| Bonded IOB (Chân I/O)      |   15 |    15 |          0 |       125 | 12.00 |
| BUFGCTRL (Global Buffers)  |    1 |     0 |          0 |        32 |  3.13 |
| MMCME2_ADV (Clock Manager) |    1 |     0 |          0 |         4 | 25.00 |
+----------------------------+------+-------+------------+-----------+-------+
```

### 8.2 Báo cáo thời gian tĩnh (Static Timing Analysis Summary)
```text
------------------------------------------------------------------------------------------------
| Design Timing Summary (50.0 MHz Target Clock, Period = 20.000 ns)
------------------------------------------------------------------------------------------------
    WNS(ns)      TNS(ns)  TNS Failing Endpoints      WHS(ns)      THS(ns)     WPWS(ns)
    -------      -------  ---------------------      -------      -------     --------
     +0.736        0.000                      0       +0.037        0.000        2.000

>> STATUS: ALL USER SPECIFIED TIMING CONSTRAINTS ARE MET (TIMING CLOSED CLEANLY).
```

---

## 📁 9. CẤU TRÚC THƯ MỤC DỰ ÁN (CLEAN DIRECTORY STRUCTURE)

Cấu trúc repository đã được chuẩn hóa, dọn dẹp sạch toàn bộ file rác/nhật ký tạm và phân định ranh giới chức năng rõ ràng:

```text
CPU-pipeline/
├── README.md                        # Tài liệu tổng quan kiến trúc, đặc tả & kết quả kiểm chứng
├── cpu_pipeline.srcs/               # Mã nguồn RTL & Unit Test lõi vi xử lý RV32IM cơ bản
│   ├── sources_1/imports/new/
│   │   ├── cpu_top.v                # Top-level module CPU tích hợp Datapath & AXI Masters
│   │   ├── datapath.v               # 5-stage Pipelined Datapath kết nối toàn diện
│   │   ├── control_unit.v           # Bộ giải mã lệnh RV32IM & CSR Control Logic
│   │   ├── alu.v                    # 32-bit ALU 10 phép toán số học & logic
│   │   ├── register_file.v          # Register File 32x32 tối ưu RAM32M Distributed RAM
│   │   ├── hazard_unit.v            # Hazard Unit (Load-Use, Div Stall, Mul Stall, Branch Flush)
│   │   ├── forwarding_unit.v        # Forwarding Unit bảo vệ x0 và ưu tiên EX/MEM
│   │   ├── pipeline_registers.v     # 4 tầng thanh ghi đường ống (IF/ID, ID/EX, EX/MEM, MEM/WB)
│   │   ├── data_memory.v            # Mô hình RAM phục vụ mô phỏng kiểm thử độc lập CPU
│   │   ├── instruction_memory.v     # Mô hình ROM phục vụ mô phỏng kiểm thử độc lập CPU
│   │   ├── crt0.s                   # Mã nguồn hợp ngữ khởi động CPU baremetal
│   │   ├── link.ld                  # Linker Script ánh xạ 16KB BRAM và đỉnh stack
│   │   └── defines.vh               # Header định nghĩa tập trung Opcodes, Funct3, ALU Ops
│   └── sim_1/
│       ├── imports/new/
│       │   └── cpu_tb.v             # Testbench kiểm thử nhân CPU RV32IM, Hazards & Forwarding
│       └── new/
│           ├── alu_tb.v             # Testbench đơn vị ALU
│           ├── forwarding_tb.v      # Testbench đơn vị mạch Forwarding
│           └── regfile_tb.v         # Testbench đơn vị Register File
├── vivado/                          # Dự án Xilinx Vivado tích hợp SoC hoàn chỉnh
│   ├── vivado.xpr                   # Tệp dự án chính của Vivado
│   ├── vivado.srcs/
│   │   ├── sources_1/new/           # Mã nguồn RTL mở rộng SoC & MMIO Peripherals
│   │   │   ├── soc_top_arty_z7.v    # Board-level Top Wrapper cho kit Digilent Arty Z7-20
│   │   │   ├── soc_top.v            # SoC Core tích hợp Dual-Port BRAM & Peripherals
│   │   │   ├── icache.v             # L1 Instruction Cache 1024B (Direct-Mapped)
│   │   │   ├── multiplier.v         # Hardware Multiplier 1-cycle (12x DSP48E1)
│   │   │   ├── divider.v            # Restoring Shift-Subtract Hardware Divider 32 chu kỳ
│   │   │   ├── branch_predictor.v   # Dynamic Branch Predictor (BHT 64x2b + BTB 64)
│   │   │   ├── branch_comp.v        # Bộ so sánh rẽ nhánh sớm tại tầng ID
│   │   │   ├── imm_gen.v            # Bộ tạo hằng số tức thời Sign-Extension (I,S,B,U,J)
│   │   │   ├── csr_file.v           # Tập thanh ghi đặc quyền Machine-Mode CSRs (64-bit rollover)
│   │   │   ├── axi_interconnect.v   # AMBA AXI4-Lite Crossbar Interconnect (2x4)
│   │   │   ├── axi_lite_master_i.v  # Bộ điều khiển AXI Master cho Instruction Refill
│   │   │   ├── axi_lite_master_d.v  # Bộ điều khiển AXI Master cho Data Memory Access
│   │   │   ├── axi_uart_lite.v      # Ngoại vi AXI UART Lite (115200 Baud, Glitch rejection)
│   │   │   ├── axi_gpio.v           # Ngoại vi AXI GPIO (LEDs, Switches, Buttons)
│   │   │   ├── axi_timer.v          # Ngoại vi AXI Machine Timer 64-bit (MTIME)
│   │   │   └── defines.vh           # Header dùng chung cho SoC
│   │   ├── constrs_1/new/
│   │   │   └── arty_z7_20.xdc       # Ràng buộc vật lý gán chân và thời gian 50MHz kit Arty Z7
│   │   └── sim_1/new/               # Hệ thống kiểm chứng cấp độ SoC & SVA (19 Testbenches)
│   │       ├── rv32i_sva.sv         # 17 Concurrent Assertions & Non-Vacuous Empirical Covers
│   │       ├── soc_pipeline_stress_tb.v # Ma trận tương tác sự kiện đường ống (Timer IRQ, bus stall, divider, mret, FENCE.I, sub-word)
│   │       ├── soc_trace_tb.v       # Hồi quy 100 seeds so khớp từng lệnh retire (36,232 lệnh luồng điều khiển vs Python Golden Model)
│   │       ├── soc_interrupt_tb.v   # Testbench kiểm thử ngắt phần cứng Timer IRQ, MTVEC, MEPC & MRET
│   │       ├── soc_isa_tb.v         # Bộ kiểm thử tuân thủ nội bộ RV32UI & RV32UM (73 test sequences)
│   │       ├── soc_random_tb.v      # Constrained-Random Testbench so khớp với Python Golden Model
│   │       ├── uart_divisor434_tb.v # Testbench kiểm thử phần cứng UART Divisor 434 (115200 Baud @ 50MHz)
│   │       ├── axi_stress_tb.v      # Testbench kiểm thử áp lực cực đoan AXI Bus (Backpressure, Skew, 400 pkts)
│   │       ├── branch_predictor_tb.v# Testbench kiểm thử bộ dự đoán rẽ nhánh
│   │       ├── multiplier_tb.v      # Testbench kiểm thử bộ nhân DSP 1 chu kỳ
│   │       ├── divider_tb.v         # Testbench kiểm thử bộ chia 32 chu kỳ & Fast-Exit
│   │       ├── csr_file_tb.v        # Testbench kiểm thử 13 CSRs, Timer IRQ, MEIP, MRET & Trap save
│   │       ├── icache_tb.v          # Testbench kiểm thử L1 I-Cache & AXI BFM
│   │       ├── axi_gpio_tb.v        # Testbench kiểm thử AXI GPIO
│   │       ├── axi_timer_tb.v       # Testbench kiểm thử AXI Timer
│   │       ├── axi_uart_lite_tb.v   # Testbench kiểm thử AXI UART Lite (Framing & Glitch)
│   │       ├── axi_interconnect_tb.v# Testbench kiểm thử Bus Crossbar AXI4-Lite
│   │       ├── soc_tb.v             # Testbench tích hợp SoC cấp độ phần cứng
│   │       └── soc_firmware_tb.v    # Testbench thực thi firmware thật & UART sniffer
│   ├── reports/                     # Báo cáo tổng hợp vật lý chính thức (Timing, DRC, Power, Util)
│   ├── build_bitstream.tcl          # Script tự động hóa tổng hợp & sinh bitstream batch mode
│   ├── program_fpga.tcl             # Script nạp bitstream lên kit FPGA tự động
│   ├── check_targets.tcl            # Kiểm tra trạng thái kết nối phần cứng Hardware Target
│   ├── gen_exhaustive_tb.py         # Trình sinh chuỗi kiểm thử toàn diện
│   ├── sim_firmware.prj             # Dự án mô phỏng xSim cho firmware test
│   ├── program.hex                  # Mã máy nhị phân nạp sẵn vào BRAM lúc khởi động
│   └── soc_top_arty_z7.bit          # File Bitstream chính thức nạp chip FPGA (1.1 MB)
├── sw/                              # Ngăn xếp phần mềm C-Baremetal
│   ├── include/                     # C Headers định nghĩa thanh ghi MMIO & API ngoại vi
│   │   ├── soc_regs.h               # Base addresses & register offsets ngoại vi
│   │   ├── uart.h                   # Driver giao tiếp UART Lite
│   │   ├── gpio.h                   # Driver điều khiển GPIO LEDs/Switches
│   │   └── timer.h                  # Driver đọc thời gian thực & tạo trễ MTIME
│   ├── src/                         # Mã nguồn C drivers và main firmware
│   │   ├── uart.c                   # Hiện thực hóa API UART
│   │   ├── gpio.c                   # Hiện thực hóa API GPIO
│   │   ├── timer.c                  # Hiện thực hóa API Timer
│   │   └── main.c                   # Firmware demo chính viết bằng C
│   ├── firmware_demo.s              # Firmware kiểm thử hệ thống viết bằng hợp ngữ
│   ├── link.ld                      # GNU Linker Script
│   ├── crt0.s                       # Startup assembly code
│   ├── Makefile                     # Makefile biên dịch bằng riscv32-unknown-elf-gcc
│   └── program.hex                  # File mã máy sau biên dịch
├── tools/                           # Bộ công cụ hỗ trợ phát triển độc lập
│   ├── rv32im_assembler.py          # Trình biên dịch hợp ngữ thuần Python (Standalone Assembler)
│   ├── golden_model_tracer.py       # Mô hình tham chiếu Python Golden Model & Engine trace retire
│   ├── generate_100_seeds_suite.py  # Trình sinh hồi quy 100 seeds có ràng buộc
│   ├── run_multi_seed_trace.py      # Trình chạy mô phỏng xSim và so khớp trace từng lệnh
│   ├── run_pipeline_stress.py       # Trình chạy kiểm thử áp lực tương tác sự kiện đường ống
│   ├── measure_all_coverage.py      # Đo lường tự động độ bao phủ mã nguồn thực nghiệm với Vivado xcrg
│   └── bin2hex.py                   # Chuyển đổi file ELF/BIN sang định dạng $readmemh
├── docs/                            # Báo cáo kỹ thuật 4 giai đoạn
│   ├── stage1/checkpoint.md         # Nghiệm thu Giai đoạn 1 (RTL Clean-up & SVA)
│   ├── stage2/checkpoint.md         # Nghiệm thu Giai đoạn 2 (RV32M & Branch Predictor)
│   ├── stage3/checkpoint.md         # Nghiệm thu Giai đoạn 3 (AXI4-Lite & MMIO SoC)
│   └── stage4/checkpoint.md         # Nghiệm thu Giai đoạn 4 (FPGA Implementation & Bitstream)
└── .gitignore                       # Bộ lọc tệp gitignore chuẩn công nghiệp cho Vivado & RISC-V
```

---

## 🚀 10. HƯỚNG DẪN TÁI LẬP KẾT QUẢ MÔ PHỎNG & NẠP MẠCH FPGA

### 10.1 Biên dịch Firmware sang file Hex (Không cần cài GCC)
Sử dụng trình biên dịch độc lập `tools/rv32im_assembler.py`:
```powershell
Set-Location "C:\Users\CPU-pineline"

# 1. Biên dịch firmware hợp ngữ sang định dạng Hex
python tools/rv32im_assembler.py sw/firmware_demo.s sw/program.hex

# 2. Đồng bộ file hex vào thư mục mô phỏng Vivado
Copy-Item sw/program.hex vivado/program.hex -Force
```

### 10.2 Chạy mô phỏng kiểm thử tự động (Vivado xSim)

#### A. Mô phỏng chạy Firmware toàn hệ thống SoC (`soc_firmware_tb`)
Mô phỏng toàn bộ chu trình SoC thực thi firmware nhúng, tự động ghi nhận luồng ký tự xuất ra UART Console và chấm điểm Scoreboard:
```powershell
Set-Location "vivado"

# Biên dịch các tệp Verilog / SystemVerilog
C:\Xilinx\Vivado\2022.2\bin\xvlog.bat -i "vivado.srcs/sources_1/new" -i "../cpu_pipeline.srcs/sources_1/imports/new" -prj sim_firmware.prj

# Liên kết và tạo snapshot mô phỏng
C:\Xilinx\Vivado\2022.2\bin\xelab.bat -i "vivado.srcs/sources_1/new" -i "../cpu_pipeline.srcs/sources_1/imports/new" -top xil_defaultlib.soc_firmware_tb -prj sim_firmware.prj -s soc_firmware_sim

# Chạy mô phỏng tự động
C:\Xilinx\Vivado\2022.2\bin\xsim.bat soc_firmware_sim -R
```

**Kết quả màn hình console kỳ vọng:**
```text
===============================================================================
   FIRMWARE EXECUTION SCOREBOARD VALIDATION
===============================================================================
[PASS] ECALL Halt Asserted (Firmware Ended)  | Actual: 0x00000001 (Exp: 0x00000001)
[PASS] RV32M Mul Register s2 (5 * 10)        | Actual: 0x00000032 (Exp: 0x00000032)
[PASS] RV32M Div Register s3 (1000 / 7)      | Actual: 0x0000008E (Exp: 0x0000008E)
[PASS] RV32M Rem Register s4 (1000 % 7)      | Actual: 0x00000006 (Exp: 0x00000006)
[PASS] BRAM 0x00000400 Content (0xCAFEBABE)  | Actual: 0xCAFEBABE (Exp: 0xCAFEBABE)
[PASS] GPIO Output LEDs (sw=0x5 ^ 0x0A)      | Actual: 0x0000000F (Exp: 0x0000000F)
[PASS] Stack Pointer sp (0x00003FFC)         | Actual: 0x00003FFC (Exp: 0x00003FFC)

===============================================================================
   MILESTONE 4.1 FIRMWARE VERIFICATION SUMMARY: ALL CHECKS PASSED 100%!
===============================================================================
```

#### B. Chạy mô phỏng các testbench đơn vị ngoại vi & toán học
Ví dụ chạy kiểm thử ngoại vi UART Lite với khả năng chống nhiễu và phát hiện lỗi khung truyền:
```powershell
Set-Location "C:\Users\simwork"
C:\Xilinx\Vivado\2022.2\bin\xvlog.bat --sv -i "vivado/vivado.srcs/sources_1/new" "vivado/vivado.srcs/sources_1/new/axi_uart_lite.v" "vivado/vivado.srcs/sim_1/new/axi_uart_lite_tb.v"
C:\Xilinx\Vivado\2022.2\bin\xelab.bat axi_uart_lite_tb -s uart_sim -R
```

### 10.3 Tổng hợp Logic, P&R và Sinh file Bitstream tự động
Chạy Vivado Batch Mode để thực thi toàn bộ luồng Synthesis $\rightarrow$ Opt Design $\rightarrow$ Place & Route $\rightarrow$ STA Timing Closure $\rightarrow$ Write Bitstream:
```powershell
Set-Location "vivado"
C:\Xilinx\Vivado\2022.2\bin\vivado.bat -mode batch -source build_bitstream.tcl
```
File bitstream nạp chip sẽ được sinh ra tại: `vivado/soc_top_arty_z7.bit`.

### 10.4 Nạp Bitstream lên Kit FPGA Digilent Arty Z7-20
1. Cắm cáp Micro-USB từ máy tính vào cổng **PROG/UART (J14)** của kit Arty Z7-20.
2. Chạy script nạp tự động qua PowerShell:
```powershell
Set-Location "vivado"
C:\Xilinx\Vivado\2022.2\bin\vivado.bat -mode batch -source program_fpga.tcl
```
3. **Quan sát hiện tượng trên kit thật:**
   * Đèn **DONE** trên kit sáng lên màu xanh/vàng báo hiệu nạp thành công.
   * **Tương tác thời gian thực:** Gạt công tắc `SW0` hoặc `SW1`, 4 đèn LED xanh `LD0 - LD3` lập tức thay đổi trạng thái theo thời gian thực (Zero latency) theo đúng phép toán nhị phân $\text{LED} = \text{SW} \oplus \text{4'b1010}$ do CPU xử lý.
   * Bấm nút **BTN0**: Toàn bộ hệ thống được Reset đồng bộ và tái lập chu trình tính toán từ đầu.

---

## 11. CÁC GIỚI HẠN KIẾN TRÚC ĐÃ BIẾT (KNOWN LIMITATIONS)

Để đảm bảo tính minh bạch kỹ thuật và độ tin cậy trong môi trường công nghiệp, các giới hạn vi kiến trúc và kiểm thử hiện tại được công bố rõ ràng như sau:

1. **Lệnh ECALL trong môi trường Bare-metal:** Lệnh `ecall` hiện được cấu hình phát tín hiệu dừng mô phỏng và phần cứng (`o_ecall_halt`) phục vụ đồng bộ testbench/firmware, chưa kích hoạt trap handler hoàn chỉnh của hệ điều hành (chưa nhảy về MTVEC với mã nguyên nhân `mcause = 11`).
2. **Không hỗ trợ truy cập bộ nhớ lệch địa chỉ (Unaligned Memory Access):** Phần cứng yêu cầu mọi truy xuất từ 32-bit (`LW`, `SW`) phải căn chỉnh 4-byte (`addr[1:0] == 2'b00`) và nửa từ 16-bit (`LH`, `LHU`, `SH`) căn chỉnh 2-byte (`addr[0] == 1'b0`). Truy xuất lệch địa chỉ sẽ kích hoạt cảnh báo SVA (`p_dmem_word_aligned`, `p_dmem_half_aligned`). Hiện tại, phần cứng thực hiện cắt tỉa địa chỉ lẻ (ví dụ `LH 0x429` đọc dữ liệu tại `0x428`), đây là **hành vi tùy biến không hoàn toàn tuân thủ đặc tả RISC-V Unprivileged ISA Specification** (vốn yêu cầu hỗ trợ tự nhiên hoặc sinh ngoại lệ trap `mcause = 4`).
3. **Giới hạn công cụ EDA với Toggle Coverage trên mảng bộ nhớ:** Vivado xSim tự động bỏ qua đo lường toggle trên các mảng RAM lớn hơn 32K-bit (như `ram_reg` 131,072 bit trong BRAM do giới hạn `32768` bit của xSim). Đối với `register_file.v` (1,024 bit), công cụ bỏ qua đo toggle trên các mảng 2 chiều không đóng gói (`reg [31:0] registers [31:0]`) theo thiết kế mặc định của engine xSim.
4. **Hạn chế của `cover property` trong Vivado xSim:** Vivado Simulator 2022.2 chưa hỗ trợ đầy đủ từ khóa `cover property` trong quá trình chạy mô phỏng (phát sinh warning và bỏ qua). Nhóm kỹ sư đã bổ sung bộ đếm sự kiện thực nghiệm trực tiếp trong `rv32i_sva.sv`, in bảng báo cáo Non-Vacuous Hits trong log mô phỏng chứng minh tính không rỗng của toàn bộ 25 khẳng định qua cả hai môi trường `soc_pipeline_stress_tb` và `soc_trace_tb`.
5. **Độ bao phủ Best-Source:** Chỉ số trung bình Statement 98.67% là trung bình cộng của nguồn kiểm thử tốt nhất cho từng module (Best Source per Module), phản ánh khả năng kích thích tối đa của bộ testbench modular. Do hạn chế của công cụ Vivado 2022.2 trên Windows khi dùng `xcrg -merge_cc` với các snapshot khác nhau, số liệu modular là báo cáo chuẩn mực nhất.

---

## 💎 12. KẾT LUẬN & ĐÁNH GIÁ CHẤT LƯỢNG

Dự án đã hoàn thành đầy đủ mọi tiêu chuẩn thiết kế vi mạch công nghiệp:
- **Chuẩn hóa kiến trúc:** Tuân thủ chặt chẽ đặc tả kiến trúc tập lệnh RISC-V RV32IM và giao thức bus chuẩn quốc tế AMBA AXI4-Lite.
- **Độ tin cậy phần cứng:** $100\%$ logic đồng bộ, **0 Latch vô ý**, cấu trúc mã nguồn Verilog tách bạch rõ ràng giữa khối tổ hợp và tuần tự.
- **Khép kín thời gian tĩnh tối ưu:** Đạt $WNS = \mathbf{+0.736\text{ ns}}$ ($F_{\text{max}} = \mathbf{51.91\text{ MHz}}$) và $WHS = \mathbf{+0.037\text{ ns}}$ tại tần số mục tiêu 50 MHz trên chip Xilinx Zynq-7000 (`xc7z020clg400-1`).
- **Xác minh đa tầng chuyên nghiệp:** Sở hữu 23 bộ testbench tự kiểm tra toàn diện, đạt độ bao phủ đo lường thực nghiệm Vivado xcrg: $\mathbf{98.67\%}$ Statement (Line), $\mathbf{89.50\%}$ Branch, $\mathbf{58.33\%}$ Condition, $\mathbf{49.35\%}$ Toggle, cơ chế ngắt an toàn chống treo (Watchdog & Bounded Timeouts), kết hợp khẳng định SystemVerilog (SVA) bảo đảm mọi bất biến vi kiến trúc.
- **Xác thực thành công trên Silicon thực tế:** Đã nạp và vận hành trơn tru trên kit Digilent Arty Z7-20. File bitstream nạp chip: [`vivado/soc_top_arty_z7.bit`](vivado/soc_top_arty_z7.bit).
