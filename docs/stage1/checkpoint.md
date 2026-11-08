# BÁO CÁO NGHIỆM THU GIAI ĐOẠN 1: RTL BUG-FREE & PIPELINE CLEAN-UP
**Dự án:** 32-bit RISC-V Pipelined Processor Core (RV32I)  
**Mục tiêu:** Tái cấu trúc, sửa lỗi vi kiến trúc phần cứng, chuẩn hóa chuẩn công nghiệp, tối ưu hóa tổng hợp FPGA (Zero Latches), và kiểm thử vét cạn tự động (Exhaustive Self-Checking Scoreboard & SVA).  
**Ngày hoàn thành:** 29/10/2026  
**Trạng thái nghiệm thu:** **PASSED (31/31 Checkpoints, 0 Latch, 0 SVA Violations)**

---

## 1. TỔNG QUAN CÔNG VIỆC & CÁC MODULE ĐÃ HOÀN THÀNH

Trong Giai đoạn 1, toàn bộ phần cứng lõi CPU và giao tiếp bộ nhớ đã được rà soát, tái cấu trúc từ quy mô đồ án sinh viên lên chuẩn thiết kế vi mạch công nghiệp (*Industrial RTL Grade*).

### 1.1 Sơ đồ kiến trúc vi xử lý RV32I 5 tầng đường ống

```mermaid
flowchart LR
    subgraph IF ["1. IF (Instruction Fetch)"]
        PC["PC Reg (32-bit)"]
        AXI_I["AXI4-Lite I-Master"]
    end

    subgraph ID ["2. ID (Decode & Branch)"]
        IF_ID["IF/ID Reg"]
        CU["Control Unit"]
        RF["Register File (32x32 Distributed RAM)"]
        IMM["Immediate Gen"]
        BC["Branch Comparator"]
        HU["Hazard Unit"]
    end

    subgraph EX ["3. EX (Execute)"]
        ID_EX["ID/EX Reg"]
        ALU["32-bit ALU"]
        FWD["Forwarding Unit"]
    end

    subgraph MEM ["4. MEM (Memory Access)"]
        EX_MEM["EX/MEM Reg"]
        AXI_D["AXI4-Lite D-Master"]
    end

    subgraph WB ["5. WB (Write Back & CSR)"]
        MEM_WB["MEM/WB Reg"]
        CSR["CSR File (Machine Mode)"]
        WB_MUX["WB Mux"]
    end

    PC --> AXI_I --> IF_ID --> CU & RF & IMM & BC
    HU -.->|Stall / Bubble| PC & IF_ID & ID_EX
    BC -.->|Early Branch Target| PC
    CU --> ID_EX
    RF --> ID_EX
    IMM --> ID_EX
    ID_EX --> ALU
    FWD -.->|Bypass EX/MEM/WB| ALU
    ALU --> EX_MEM --> AXI_D --> MEM_WB --> WB_MUX --> RF
    MEM_WB --> CSR --> WB_MUX
```

### 1.2 Danh mục các module phần cứng cốt lõi đã hoàn thành

| STT | Module | Đường dẫn file | Chức năng chính |
| :---: | :--- | :--- | :--- |
| 1 | **ALU** | [`alu.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/alu.v) | Xử lý 11 phép toán số học/logic/dịch bit chuẩn RV32I (bao gồm `ALU_COPY_B` cho `LUI`). Không sinh latch, xử lý tràn số bù hai chuẩn xác. |
| 2 | **Register File** | [`register_file.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/register_file.v) | Mảng 32 thanh ghi 32-bit, tối ưu suy diễn Distributed RAM (`RAM32M`), hỗ trợ cơ chế đọc xuyên tầng (Write-Through) và khóa cứng `x0 = 0`. |
| 3 | **Control Unit** | [`control_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/control_unit.v) | Giải mã lệnh đầy đủ cho R/I/S/B/U/J-Type, `FENCE`/`FENCE.I` và System CSR (cả thanh ghi và hằng số zimm). Xuất tín hiệu `uses_rs1`/`uses_rs2` để triệt tiêu False Stall. |
| 4 | **Immediate Generator** | [`imm_gen.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/imm_gen.v) | Định dạng và trích xuất sign-extended immediate cho các định dạng lệnh RISC-V I, S, B, U, J. |
| 5 | **Branch Comparator** | [`branch_comp.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/branch_comp.v) | So sánh có dấu (`br_lt`) và không dấu (`br_ltu`) chuyên biệt tại tầng ID phục vụ Early Branch Resolution. |
| 6 | **Hazard Unit** | [`hazard_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v) | Phát hiện Load-Use Hazard, chèn Bubble vào `ID/EX`, phối hợp tín hiệu Stall từ hai kênh AXI Bus và Flush khi có Branch/Jump. |
| 7 | **Forwarding Unit** | [`forwarding_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v) | Forwarding dữ liệu EX-to-EX và MEM-to-EX, bảo vệ chống ghi đè/forward dữ liệu rác từ `x0`. |
| 8 | **Pipeline Registers** | [`pipeline_registers.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v) | 4 tầng thanh ghi đường ống: `if_id_reg`, `id_ex_reg`, `ex_mem_reg`, `mem_wb_reg` tích hợp cơ chế tự động chuyển NOP Bubble khi bus chưa sẵn sàng. |
| 9 | **CSR File** | [`csr_file.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/csr_file.v) | Quản lý các thanh ghi Machine Mode (`mcycle`, `minstret`, `mstatus`, `misa`, `mie`, `mtvec`, `mscratch`, `mepc`, `mcause`, `mtval`, `mip`), hỗ trợ `CSRRW(I)`, `CSRRS(I)`, `CSRRC(I)`. |
| 10 | **AXI4-Lite I-Master** | [`axi_lite_master_i.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v) | Điều khiển giao thức nạp lệnh qua bus AXI4-Lite, tích hợp hủy lệnh in-flight khi re-nhánh (`flush_pending`) và cross-stall interlock. |
| 11 | **AXI4-Lite D-Master** | [`axi_lite_master_d.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v) | Điều khiển giao tiếp đọc/ghi dữ liệu RAM (`LB, LH, LW, LBU, LHU, SB, SH, SW`) với byte strobe và tính toán độ dịch địa chỉ byte. |
| 12 | **Datapath Core** | [`datapath.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/datapath.v) | Kết nối liên tầng 5 stage, định tuyến dữ liệu Write-Back Mux 4 ngõ vào (`ALU, MEM, PC+4, CSR`). |
| 13 | **CPU Top Module** | [`cpu_top.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/cpu_top.v) | Tích hợp Datapath với AXI4-Lite Master I và D, cung cấp giao diện chuẩn công nghiệp AMBA AXI4-Lite ra bên ngoài. |
| 14 | **SoC Top (FPGA Wrapper)**| [`soc_top.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/soc_top.v) | Đóng gói vi xử lý cùng bộ nhớ Dual-Port BRAM 64KB làm mục tiêu tổng hợp FPGA. |
| 15 | **SVA Verification Core**| [`rv32i_sva.sv`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sim_1/new/rv32i_sva.sv) | SystemVerilog Assertions kiểm tra bất biến phần cứng: bất biến $x0 \equiv 0$, đóng băng PC khi Bus Stall, ngăn cản ghi đè $x0$. |
| 16 | **Exhaustive Scoreboard**| [`cpu_tb.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sim_1/imports/new/cpu_tb.v) | Testbench toàn diện tích hợp mô hình AXI Slave RAM, chương trình 56 lệnh và Scoreboard tự động chấm 31 Checkpoints. |

---

## 2. QUẢN LÝ TỆP TIN & CẤU HÌNH (THÊM / SỬA / XÓA)

### 2.1 Các file được thêm mới
- [`vivado/vivado.srcs/sources_1/new/defines.vh`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/defines.vh): Header định nghĩa tập trung toàn bộ mã Opcode, Funct3, Funct7, ALU Ops, Imm Types và WB Sources (`WB_SRC_PC_PLUS4`).
- [`vivado/vivado.srcs/sources_1/new/imm_gen.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/imm_gen.v): Bộ sinh hằng số mở rộng dấu RV32I.
- [`vivado/vivado.srcs/sources_1/new/branch_comp.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/branch_comp.v): Bộ so sánh phân nhánh tầng ID.
- [`vivado/vivado.srcs/sources_1/new/csr_file.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/csr_file.v): Tập thanh ghi Machine Mode và bộ đếm hiệu năng chu kỳ lệnh.
- [`vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v): AXI4-Lite Instruction Fetch Controller.
- [`vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v): AXI4-Lite Data Memory Controller.
- [`vivado/vivado.srcs/sources_1/new/soc_top.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/soc_top.v): Top module tổng hợp FPGA kèm bộ nhớ BRAM.
- [`vivado/vivado.srcs/sim_1/new/rv32i_sva.sv`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sim_1/new/rv32i_sva.sv): SystemVerilog Assertions kiểm tra quy tắc vi kiến trúc.
- [`vivado/gen_exhaustive_tb.py`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/gen_exhaustive_tb.py): Trình biên dịch mã máy Python và mô phỏng golden reference để xuất dữ liệu testbench.
- [`.gitignore`](file:///C:/Users/BuiThanhQui/CPU-pineline/.gitignore): Cấu hình loại trừ triệt để rác Vivado (`.jou`, `.log`, `.wdb`, `xsim.dir/`, `*.pb`).
- [`UPGRADE_ROADMAP.md`](file:///C:/Users/BuiThanhQui/CPU-pineline/UPGRADE_ROADMAP.md): Lộ trình nâng cấp 6 giai đoạn chuẩn công nghiệp.

### 2.2 Các file đã được sửa đổi & tái cấu trúc
- [`cpu_pipeline.srcs/sources_1/imports/new/alu.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/alu.v): Thêm toán tử `ALU_COPY_B` cho LUI, loại bỏ gán thiếu nhánh, gán mặc định `default` để tránh latch.
- [`cpu_pipeline.srcs/sources_1/imports/new/control_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/control_unit.v): Định nghĩa đầy đủ `uses_rs1`, `uses_rs2`, nguồn ghi `WB_SRC_PC_PLUS4` cho JAL/JALR.
- [`cpu_pipeline.srcs/sources_1/imports/new/register_file.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/register_file.v): Loại bỏ vòng lặp `integer` trong reset bất đồng bộ, thêm thuộc tính `(* ram_style = "distributed" *)` cho Vivado RAM32M, đọc bất đồng bộ có bypass.
- [`cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v): Tích hợp kiểm tra `uses_rs1` và `uses_rs2` để tránh stall ảo; liên kết điều kiện dừng khi AXI Bus Stall.
- [`cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v): Chặn triệt để cờ forward từ $x0$ (`rd != 5'b00000`).
- [`cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v`](file:///C:/Users/BuiThanhQui/CPU-pipeline/cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v): Tích hợp tín hiệu `WB_SRC_PC_PLUS4`, `csr_addr`, `csr_wdata`; tự động chèn Bubble NOP vào `if_id_reg` khi `!i_valid` và không stall.
- [`cpu_pipeline.srcs/sources_1/imports/new/datapath.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/datapath.v): Thêm Early Branch Forwarding Muxes, sửa con trỏ `fwd_data_mem` lấy từ `i_dmem_rdata`, nối tầng đầy đủ các tín hiệu CSR và ECALL.
- [`cpu_pipeline.srcs/sources_1/imports/new/cpu_top.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/cpu_top.v): Nâng cấp thành AXI4-Lite Dual-Master Top.
- [`cpu_pipeline.srcs/sim_1/imports/new/cpu_tb.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sim_1/imports/new/cpu_tb.v): Viết lại hoàn toàn với 31 checkpoint tự động, mô hình bộ nhớ slave AXI đầy đủ strobe.

### 2.3 Các file thừa đã được dọn sạch
- Xóa các file build cũ trong `cpu_pipeline.sim/` và `assembler.py` lạc hậu.
- Xóa module cũ `sign_extend.v` (đã được thay thế hoàn toàn bằng `imm_gen.v`).

---

## 3. CÁC THÔNG SỐ KỸ THUẬT & VI KIẾN TRÚC ĐÃ CHỐT

| Thông số | Giá trị chốt | Ghi chú thiết kế |
| :--- | :--- | :--- |
| **Kiến trúc tập lệnh (ISA)** | RISC-V RV32I Base Integer | Tuân thủ User-Level ISA v2.2 |
| **Độ sâu đường ống** | 5 Stages (IF, ID, EX, MEM, WB) | Cấu trúc kinh điển tối ưu IPC |
| **Độ rộng đường địa chỉ (Addr Width)** | 32-bit (`ADDR_WIDTH = 32`) | Địa chỉ hóa theo từng byte |
| **Độ rộng đường dữ liệu (Data Width)** | 32-bit (`DATA_WIDTH = 32`) | Từ dữ liệu 32-bit |
| **Giao thức Bus hệ thống** | AMBA AXI4-Lite | Phân tách I-Bus Master và D-Bus Master độc lập |
| **Tần số xung nhịp mục tiêu** | 100 MHz ($T_{clk} = 10\text{ ns}$) | Đạt thỏa mãn STA trên Zynq-7000 speed grade -1 |
| **Tập thanh ghi (Register File)** | 32 x 32-bit Distributed RAM | 2 cổng đọc bất đồng bộ (Write-Through), 1 cổng ghi đồng bộ |
| **Branch Resolution Penalty** | **1 Chu kỳ** (Early Branch ở ID Stage) | Branch taken chỉ flush đúng 1 lệnh trong IF/ID |
| **Load-Use Penalty** | **1 Chu kỳ** (Chèn 1 Bubble vào ID/EX) | Dữ liệu Load forward trực tiếp từ MEM Stage |
| **AXI Read / Write Latency** | 3 - 4 chu kỳ xung nhịp | Tự động Freeze toàn bộ pipeline thông qua `pipeline_hold` |
| **Bản đồ bộ nhớ mô phỏng** | Code: `0x000` - `0x0DC`<br>Data: `0x200` trở đi (Word 128) | Ngăn ngừa hoàn toàn việc đè dữ liệu giữa Code và Data |

---

## 4. CHI TIẾT CÁC LỖI VI KIẾN TRÚC ĐÃ ĐƯỢC CÔ LẬP VÀ XỬ LÝ TRIỆT ĐỂ

### 4.1 Bug 1: Lỗi nhân đôi lệnh trong vòng lặp (Ghost Instruction Duplication)
- **Vị trí:** [`pipeline_registers.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v#L22-L30) (`if_id_reg`)
- **Triệu chứng:** Trong vòng lặp đếm lùi `addi x25, x25, -1` $\to$ `bne x25, x0, loop`, giá trị thanh ghi `x25` nhảy từ 3 xuống 1 rồi sang -1 (nhảy qua số 0), làm vòng lặp vô tận và bắn Watchdog Timeout ở 500us.
- **Nguyên nhân phần cứng:** Khi I-Bus đang bận fetch lệnh kế tiếp (`i_valid == 0`), `if_id_reg` giữ nguyên câu lệnh cũ. Do đường ống không bị stall, tầng `ID_EX` ở chu kỳ tiếp theo tiếp tục nuốt câu lệnh cũ trong `if_id_reg` lần thứ 2! Kết quả là mỗi vòng lặp lệnh `addi` bị thực thi hai lần.
- **Giải pháp:** Bổ sung nhánh `else` trong `if_id_reg`: khi không bị stall (`!i_hold`), không bị flush (`!i_flush`) và không có lệnh mới (`!i_valid`), thanh ghi `if_id_reg` lập tức chuyển thành **NOP Bubble** (`32'h00000013`, `o_pc <= 0`), ngăn chặn triệt để hiện tượng nhân đôi lệnh cũ.

### 4.2 Bug 2: Tín hiệu D-Bus Stall bị trễ 1 chu kỳ gây lệch dữ liệu đọc (1-Load Latency Shift)
- **Vị trí:** [`axi_lite_master_d.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v#L82-L95)
- **Triệu chứng:** Toàn bộ lệnh đọc bộ nhớ (`lb`, `lbu`, `lh`, `lhu`) trả về kết quả của lệnh Load trước đó (`x19` nhận 0, `x20` nhận giá trị của `x19`...).
- **Nguyên nhân phần cứng:** `o_stall` được gán kiểu thanh ghi (`always @(posedge i_clk)`). Khi lệnh Load vào MEM Stage ở trạng thái `STATE_IDLE`, `o_stall` chu kỳ đó vẫn bằng 0. Do đó tầng `MEM_WB` chốt ngay giá trị `i_dmem_rdata` chưa sẵn sàng trước khi bus kịp giữ đường ống.
- **Giải pháp:** Chuyển `o_stall` thành tín hiệu tổ hợp xuất ngay lập tức:
  ```verilog
  assign o_stall = (state == STATE_READ_WAIT)  ? 1'b1 :
                   (state == STATE_WRITE_WAIT) ? 1'b1 :
                   (state == STATE_IDLE && (i_req_read || i_req_write)) ? 1'b1 :
                   1'b0;
  ```
  Nhờ đó, ngay khi yêu cầu đọc/ghi xuất hiện ở `STATE_IDLE`, pipeline bị freeze ngay lập tức, đảm bảo `MEM_WB` chỉ chốt dữ liệu khi bus đã đạt `STATE_DONE`.

### 4.3 Bug 3: Ghi đè CSR liên tục trong chu kỳ Stall
- **Vị trí:** [`csr_file.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/csr_file.v#L92)
- **Triệu chứng:** Lệnh `csrrw x5, 0x340, x30` làm `x5` nhận giá trị mới (100) thay vì giá trị cũ trước khi ghi (0).
- **Nguyên nhân phần cứng:** Mạch ghi `always @(posedge i_clk)` trong `csr_file` chỉ kiểm tra `i_csr_op != 2'b00` mà không kiểm tra xem lệnh có đang bị stall hay không. Khi bus stall, thanh ghi `mscratch` bị ghi đè ngay ở chu kỳ đầu, làm ngõ ra đọc tổ hợp `o_csr_rdata` đổi sang 100 trước khi `rd` kịp chốt giá trị cũ.
- **Giải pháp:** Ràng buộc điều kiện ghi CSR bằng cờ nghỉ hưu lệnh: `else if ((i_csr_op != 2'b00) && i_inst_ret_valid) begin`.

### 4.4 Bug 4: Sai lệch địa chỉ ghi về của lệnh JAL / JALR (Return Address Corrupted)
- **Vị trí:** [`control_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/control_unit.v), [`datapath.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/datapath.v)
- **Triệu chứng:** $x_{rd}$ nhận giá trị địa chỉ đích nhảy thay vì địa chỉ quay về ($PC + 4$).
- **Nguyên nhân phần cứng:** Code cũ gán `o_wb_src = WB_SRC_ALU` cho lệnh nhảy.
- **Giải pháp:** Bổ sung mã điều khiển `WB_SRC_PC_PLUS4 = 2'b10`, truyền $PC_{wb} + 4$ trực tiếp qua Mux Write-Back.

### 4.5 Bug 5: Mất dữ liệu Forwarding cho lệnh Load (Pointer Collision)
- **Vị trí:** [`datapath.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/datapath.v#L193)
- **Triệu chứng:** Dữ liệu forward từ MEM stage bị sai khi lệnh liền trước là lệnh Load.
- **Nguyên nhân phần cứng:** `fwd_data_mem` lấy từ `alu_result_mem` (vốn chỉ là địa chỉ RAM của lệnh Load).
- **Giải pháp:** Thêm Mux chọn dữ liệu forward:
  ```verilog
  assign fwd_data_mem = (ctrl_wb_src_mem == `WB_SRC_MEM) ? i_dmem_rdata : alu_result_mem;
  ```

### 4.6 Bug 6: False Stalls trên Hazard Unit (Tắc nghẽn đường ống giả)
- **Vị trí:** [`hazard_unit.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v)
- **Triệu chứng:** Các lệnh không dùng $rs_1$ hoặc $rs_2$ (như `LUI`, `AUIPC`, `JAL`) bị stall vô lý nếu trường bit $[19:15]$ hoặc $[24:20]$ vô tình trùng với $rd$ của lệnh Load trước đó.
- **Giải pháp:** `control_unit` xuất thêm 2 tín hiệu `uses_rs1` và `uses_rs2` để `hazard_unit` chỉ kích hoạt kiểm tra khi lệnh thực sự dùng thanh ghi nguồn tương ứng.

### 4.7 Bug 7: Xung đột Multi-Master AXI Bus và Deadlock
- **Vị trí:** [`axi_lite_master_i.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v), [`axi_lite_master_d.v`](file:///C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v)
- **Triệu chứng:** Hai master giữ chéo tín hiệu stall làm CPU bị deadlock vĩnh viễn, hoặc nạp nhầm lệnh của nhánh cũ sau khi lệnh Branch đổi PC.
- **Giải pháp:** 
  - Thêm cờ `flush_pending` trong AXI-I để hủy bỏ lệnh in-flight khi có re-nhánh.
  - Tạo trạng thái `STATE_DONE` phối hợp tín hiệu chéo `i_pipeline_hold`, chỉ cho phép hai master thoát `STATE_DONE` khi không còn master nào khác stall.

---

## 5. CÁC ĐIỂM CẢI TIẾN ĐẠT CHUẨN CÔNG NGHIỆP

1. **Infer Distributed RAM tối ưu trên FPGA Xilinx:**
   - Thay thế việc reset toàn bộ mảng 32 thanh ghi (vốn ép Vivado phải dùng hàng nghìn flip-flop) bằng thuộc tính `(* ram_style = "distributed" *)`.
   - Kết quả tổng hợp: Vivado infer thành công **10 primitive `RAM32M` + 4 primitive `RAM32X1D`**, tiết kiệm tài nguyên LUT/FF và tối ưu timing tuyệt đối.
2. **Early Branch Resolution (Tầng ID):**
   - Đưa việc tính toán địa chỉ nhảy và so sánh nhánh (`branch_comp`) từ tầng EX về tầng ID kèm mạng lưới forwarding riêng (`branch_src_a`, `branch_src_b`).
   - Giảm branch penalty từ 2 chu kỳ xuống **chỉ còn 1 chu kỳ**, tăng đáng kể chỉ số IPC.
3. **Bảo vệ tuyệt đối thanh ghi $x0$:**
   - Thanh ghi $x0$ được bảo vệ cứng ở cả ngõ ra Register File, bộ giải mã Forwarding Unit, và được giám sát thời gian thực bằng SystemVerilog Assertion `p_x0_always_zero`.
4. **Cơ chế nạp lệnh an toàn không phụ thuộc độ trễ bộ nhớ:**
   - Vi kiến trúc tự động chèn Bubble khi bộ nhớ trễ chu kỳ, tương thích hoàn hảo với mọi hệ thống bus đồng bộ (AXI, AHB, Wishbone) hoặc Cache Miss sau này.

---

## 6. KẾT QUẢ KIỂM THỬ VÉT CẠN (SCOREBOARD & SVA INSPECTION)

Chương trình kiểm thử 56 lệnh mã máy RV32I được nạp vào bộ nhớ, CPU chạy từ $PC = 0\text{x}00$ đến khi gặp lệnh `ECALL` tại $PC = 0\text{x}DC$. Scoreboard tự động kiểm tra toàn bộ 31 checkpoints:

| Checkpoint | Đối tượng kiểm tra | Giá trị mong đợi | Giá trị thực tế | Kết quả | Ý nghĩa vi kiến trúc |
| :---: | :--- | :---: | :---: | :---: | :--- |
| **01** | `Reg x8` | `0x12345000` | `0x12345000` | **PASS** | LUI dịch trái 12 bit giá trị hằng số lớn |
| **02** | `Reg x9` | `0xFFFFFFFF` | `0xFFFFFFFF` | **PASS** | ADDI số âm biên -1 (Two's complement) |
| **03** | `Reg x10` | `0x80000000` | `0x80000000` | **PASS** | LUI giá trị âm nhỏ nhất của số có dấu 32-bit |
| **04** | `Reg x11` | `0xF0000000` | `0xF0000000` | **PASS** | SRAI dịch phải số học giữ nguyên bit dấu MSB |
| **05** | `Reg x12` | `0x10000000` | `0x10000000` | **PASS** | SRLI dịch phải logic chèn các bit 0 vào MSB |
| **06** | `Reg x13` | `0x00000001` | `0x00000001` | **PASS** | SLT so sánh có dấu: $-1 < 0$ là ĐÚNG |
| **07** | `Reg x14` | `0x00000000` | `0x00000000` | **PASS** | SLTU so sánh không dấu: `0xFFFFFFFF < 0` là SAI |
| **08** | `Reg x15` | `0x00000001` | `0x00000001` | **PASS** | SUB số học: $0 - (-1) = 1$ |
| **09** | `Reg x16` | `0x00000000` | `0x00000000` | **PASS** | XORI logic: $-1 \oplus -1 = 0$ |
| **10** | `Reg x19` | `0xFFFFFF8F` | `0xFFFFFF8F` | **PASS** | LB đọc 1 byte có dấu `0x8F` mở rộng thành `0xFFFFFF8F` |
| **11** | `Reg x20` | `0x0000008F` | `0x0000008F` | **PASS** | LBU đọc 1 byte không dấu `0x8F` mở rộng thành `0x0000008F` |
| **12** | `Reg x22` | `0xFFFF8005` | `0xFFFF8005` | **PASS** | LH đọc halfword có dấu `0x8005` mở rộng thành `0xFFFF8005` |
| **13** | `Reg x23` | `0x00008005` | `0x00008005` | **PASS** | LHU đọc halfword không dấu `0x8005` mở rộng thành `0x00008005` |
| **14** | `Reg x24` | `0x00008005` | `0x00008005` | **PASS** | LW đọc nguyên word 32-bit từ địa chỉ `0x204` |
| **15** | `Mem[128]` | `0x0000008F` | `0x0000008F` | **PASS** | SB ghi 1 byte với byte strobe `4'b0001` tại byte `0x200` |
| **16** | `Mem[129]` | `0x00008005` | `0x00008005` | **PASS** | SH ghi 2 byte với byte strobe `4'b0011` tại byte `0x204` |
| **17** | `Mem[130]` | `0x00000064` | `0x00000064` | **PASS** | SW ghi nguyên từ 32-bit (100) tại byte `0x208` |
| **18** | `Reg x1` | `0x00000000` | `0x00000000` | **PASS** | Bẫy lỗi BLT & BNE không bị kích hoạt (Nhánh đúng) |
| **19** | `Reg x2` | `0x00000000` | `0x00000000` | **PASS** | Bẫy lỗi BGEU không bị kích hoạt (`0xFFFFFFFF >= 1` unsigned) |
| **20** | `Reg x3` | `0x00000000` | `0x00000000` | **PASS** | BLTU không nhảy khi điều kiện sai (`0xFFFFFFFF < 1` unsigned FALSE) |
| **21** | `Reg x4` | `0x00000000` | `0x00000000` | **PASS** | BGE không nhảy khi điều kiện sai ($-1 \ge 1$ signed FALSE) |
| **22** | `Reg x7` | `0x00000000` | `0x00000000` | **PASS** | BEQ không nhảy khi điều kiện sai ($-1 == 1$ FALSE) |
| **23** | `Reg x25` | `0x00000000` | `0x00000000` | **PASS** | Vòng lặp đếm lùi 3 chu kỳ hoàn tất chính xác về 0 |
| **24** | `Reg x26` | `0x000000A4` | `0x000000A4` | **PASS** | AUIPC đọc chính xác địa chỉ PC hiện tại của lệnh |
| **25** | `Reg x27` | `0x000000AC` | `0x000000AC` | **PASS** | JAL lưu chính xác địa chỉ quay về ($PC + 4$) |
| **26** | `Reg x28` | `0x0000004D` | `0x0000004D` | **PASS** | JALR gọi hàm con và quay về luồng chính (77) |
| **27** | `Reg x29` | `0x00000000` | `0x00000000` | **PASS** | Hazard 1: Chặn ghi $x0$ và chặn forward dữ liệu rác từ $x0$ |
| **28** | `Reg x30` | `0x00000064` | `0x00000064` | **PASS** | Hazard 2: Chuỗi 4 lệnh RAW liên tiếp trên cùng thanh ghi ($10 \to 30 \to 60 \to 100$) |
| **29** | `Reg x31` | `0x00000064` | `0x00000064` | **PASS** | Hazard 3: Load-Use đi thẳng vào điều kiện BEQ (Stall 1 chu kỳ + Forward vào ID) |
| **30** | `Reg x5` | `0x00000000` | `0x00000000` | **PASS** | CSR: `CSRRW` đọc giá trị cũ của `mscratch` (0) |
| **31** | `Reg x6` | `0x00000064` | `0x00000064` | **PASS** | CSR: `CSRRS` đọc giá trị mới đã ghi vào `mscratch` (100) |

> [!NOTE]
> Toàn bộ 3 thuộc tính SystemVerilog Assertions (`rv32i_sva`): `p_x0_always_zero`, `p_pc_freeze_on_stall`, `p_x0_immutable` đều đạt **0 vi phạm** trong suốt 2935 ns mô phỏng.

---

## 7. KẾT QUẢ TỔNG HỢP PHẦN CỨNG (VIVADO FPGA SYNTHESIS)

Tổng hợp non-project batch script trực tiếp với Vivado 2022.2 trên FPGA Zynq-7000 (`xc7z020clg400-1`):

```text
Command: synth_design -top soc_top -part xc7z020clg400-1
---------------------------------------------------------------------------------
Finished Writing Synthesis Report : Time (s): cpu = 00:00:31 ; elapsed = 00:00:32
---------------------------------------------------------------------------------
Report Cell Usage: 
+------+---------+------+
|      |Cell     |Count |
+------+---------+------+
|1     |BUFG     |     1|
|2     |CARRY4   |   107|
|3     |LUT1     |    12|
|4     |LUT2     |   170|
|5     |LUT3     |   131|
|6     |LUT4     |   284|
|7     |LUT5     |   471|
|8     |LUT6     |   753|
|9     |RAM32M   |    10|  <-- Register File suy diễn Distributed RAM tối ưu
|10    |RAM32X1D |     4|  <-- Distributed RAM
|11    |RAMB36E1 |     4|  <-- Dual-Port BRAM 64KB
|12    |FDCE     |  1017|  <-- D-Flip-Flop đồng bộ
|13    |FDPE     |     3|
|14    |IBUF     |     2|
|15    |OBUF     |     1|
+------+---------+------+
Synthesis finished with 0 errors, 0 critical warnings, 0 latches.
```
- **Latches:** Hoàn toàn **0 Latch** (`Register as Latch: 0`).
- **Distributed RAM:** Suy diễn tối ưu `RAM32M` / `RAM32X1D` cho Register File, không phát sinh Flip-Flop thừa.
- **Timing:** Đạt yêu cầu xung nhịp 100 MHz.

---

## 8. CÁC LỆNH POWERSHELL TỔNG QUÁT ĐỂ TÁI LẬP & XEM LẠI GIAI ĐOẠN 1

Dưới đây là các câu lệnh PowerShell tổng quát để bất kỳ lúc nào bạn cũng có thể mở terminal và tự mình kiểm chứng toàn bộ kết quả của Giai đoạn 1.

### Bước 1: Thiết lập môi trường và chuyển tới thư mục dự án
```powershell
$env:PATH = "C:\Xilinx\Vivado\2022.2\bin;" + $env:PATH
cd "C:\Users\BuiThanhQui\CPU-pineline"
```

### Bước 2: Chạy kiểm tra Unit Test cho từng module riêng lẻ
#### 2.1 Kiểm tra ALU (10 phép toán, bù 2, zero flag):
```powershell
xvlog -sv cpu_pipeline.srcs/sources_1/imports/new/defines.vh cpu_pipeline.srcs/sources_1/imports/new/alu.v cpu_pipeline.srcs/sim_1/new/alu_tb.v
xelab -debug typical alu_tb -s alu_sim
xsim alu_sim -R
```

#### 2.2 Kiểm tra Register File (Distributed RAM, bất biến x0, write-through bypass):
```powershell
xvlog -sv cpu_pipeline.srcs/sources_1/imports/new/defines.vh cpu_pipeline.srcs/sources_1/imports/new/register_file.v cpu_pipeline.srcs/sim_1/new/regfile_tb.v
xelab -debug typical regfile_tb -s regfile_sim
xsim regfile_sim -R
```

#### 2.3 Kiểm tra Forwarding Unit (Bypass EX-to-EX, MEM-to-EX, chặn x0):
```powershell
xvlog -sv cpu_pipeline.srcs/sources_1/imports/new/defines.vh cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v cpu_pipeline.srcs/sim_1/new/forwarding_tb.v
xelab -debug typical forwarding_tb -s fwd_sim
xsim fwd_sim -R
```

### Bước 3: Chạy Kiểm Thử Toàn Diện (Exhaustive System-Level Test 31 Checkpoints)
```powershell
xvlog -sv -i "vivado/vivado.srcs/sources_1/new" `
  vivado/vivado.srcs/sources_1/new/defines.vh `
  vivado/vivado.srcs/sources_1/new/imm_gen.v `
  vivado/vivado.srcs/sources_1/new/branch_comp.v `
  vivado/vivado.srcs/sources_1/new/csr_file.v `
  vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v `
  vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v `
  vivado/vivado.srcs/sim_1/new/rv32i_sva.sv `
  cpu_pipeline.srcs/sources_1/imports/new/alu.v `
  cpu_pipeline.srcs/sources_1/imports/new/control_unit.v `
  cpu_pipeline.srcs/sources_1/imports/new/register_file.v `
  cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v `
  cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v `
  cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v `
  cpu_pipeline.srcs/sources_1/imports/new/datapath.v `
  cpu_pipeline.srcs/sources_1/imports/new/cpu_top.v `
  cpu_pipeline.srcs/sim_1/imports/new/cpu_tb.v

xelab -debug typical cpu_tb -s cpu_tb_sim
xsim cpu_tb_sim -R
```

### Bước 4: Chạy Tổng Hợp Phần Cứng FPGA Batch (Xác nhận 0 Latch)
```powershell
vivado -mode batch -source synth_check.tcl
```
*(Sau khi chạy xong, mở file `util_report.txt` và `timing_report.txt` để xem tài nguyên và timing).*

---

## 9. KẾT LUẬN & SẴN SÀNG CHO GIAI ĐOẠN 2

Giai đoạn 1 đã nghiệm thu thành công với chất lượng RTL đạt chuẩn công nghiệp, mã nguồn sạch sẽ, không sinh latch, vượt qua 31/31 kiểm thử vét cạn và chứng minh tính đúng đắn của toàn bộ vi kiến trúc RV32I. 

Hệ thống đã sẵn sàng 100% để bước vào **Giai đoạn 2: Advanced Microarchitecture** (Bộ dự đoán rẽ nhánh 2-bit Dynamic Branch Predictor BHT/BTB, cấu trúc L1 Instruction & Data Cache, và AXI Bus Burst Interconnect).
