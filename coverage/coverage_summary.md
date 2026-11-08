# Vivado xSim / xcrg Code Coverage Verification Report

Generated using `xsim -cc_type sbct` (Statement, Branch, Condition, Toggle) and `xcrg`.

## 1. Testbench DUT Specific Coverage

| Testbench | DUT File | Statement (Line) % | Branch % | Condition % | Toggle % |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `alu_tb` | `alu.v` | 100.00% | 85.71% | 33.33% | 65.50% |
| `forwarding_tb` | `forwarding_unit.v` | 80.00% | 66.67% | 75.00% | 51.92% |
| `control_unit_tb` | `control_unit.v` | 98.60% | 92.86% | 100.00% | 89.09% |
| `csr_file_tb` | `csr_file.v` | 94.83% | 92.50% | 100.00% | 21.62% |
| `regfile_tb` | `register_file.v` | 100.00% | 87.50% | 100.00% | 0.49% |
| `branch_predictor_tb` | `branch_predictor.v` | 95.24% | 94.12% | 0.00% | 0.71% |
| `multiplier_tb` | `multiplier.v` | 83.33% | 80.00% | 0.00% | 91.45% |
| `divider_tb` | `divider.v` | 97.56% | 95.24% | 100.00% | 92.84% |
| `icache_tb` | `icache.v` | 98.36% | 92.31% | 100.00% | 0.79% |
| `axi_gpio_tb` | `axi_gpio.v` | 100.00% | 100.00% | 0.00% | 33.45% |
| `axi_timer_tb` | `axi_timer.v` | 100.00% | 90.91% | 0.00% | 27.85% |
| `axi_uart_lite_tb` | `axi_uart_lite.v` | 100.00% | 95.83% | 100.00% | 42.37% |
| `axi_interconnect_tb` | `axi_interconnect.v` | 100.00% | 100.00% | 100.00% | 23.02% |
| `cpu_tb` | `cpu_top.v` | 0.00% | 0.00% | 0.00% | 75.99% |
| `soc_tb` | `soc_top.v` | 98.28% | 77.27% | 0.00% | 20.48% |
| `axi_stress_tb` | `axi_interconnect.v` | 90.14% | 52.94% | 26.23% | 13.89% |
| `uart_divisor434_tb` | `axi_uart_lite.v` | 98.32% | 85.42% | 100.00% | 26.62% |
| `soc_isa_tb` | `soc_top.v` | 70.69% | 68.18% | 0.00% | 20.73% |
| `soc_random_tb` | `soc_top.v` | 53.45% | 40.91% | 0.00% | 11.99% |
| `soc_interrupt_tb` | `soc_top.v` | 53.45% | 40.91% | 0.00% | 11.40% |
| `soc_firmware_tb` | `soc_top.v` | 74.14% | 77.27% | 0.00% | 46.15% |

## 2. RTL Core & Peripheral Modules Coverage

| Module File | Best Testbench Source | Stmt % | Branch % | Cond % | Toggle % |
| :--- | :--- | :---: | :---: | :---: | :---: |
| `alu.v` | `alu_tb` | **100.00%** | **85.71%** | **33.33%** | **65.50%** |
| `axi_gpio.v` | `axi_gpio_tb` | **100.00%** | **100.00%** | **0.00%** | **33.45%** |
| `axi_interconnect.v` | `axi_interconnect_tb` | **100.00%** | **100.00%** | **100.00%** | **23.02%** |
| `axi_lite_master_d.v` | `cpu_tb` | **93.24%** | **81.40%** | **100.00%** | **70.00%** |
| `axi_timer.v` | `axi_timer_tb` | **100.00%** | **90.91%** | **0.00%** | **27.85%** |
| `axi_uart_lite.v` | `axi_uart_lite_tb` | **100.00%** | **95.83%** | **100.00%** | **42.37%** |
| `branch_comp.v` | `cpu_tb` | **100.00%** | **0.00%** | **100.00%** | **0.00%** |
| `branch_predictor.v` | `soc_firmware_tb` | **95.24%** | **94.12%** | **0.00%** | **1.55%** |
| `control_unit.v` | `control_unit_tb` | **98.60%** | **92.86%** | **100.00%** | **89.09%** |
| `cpu_top.v` | `cpu_tb` | **0.00%** | **0.00%** | **0.00%** | **75.99%** |
| `csr_file.v` | `csr_file_tb` | **94.83%** | **92.50%** | **100.00%** | **21.62%** |
| `datapath.v` | `cpu_tb` | **100.00%** | **98.11%** | **100.00%** | **52.91%** |
| `divider.v` | `divider_tb` | **97.56%** | **95.24%** | **100.00%** | **92.84%** |
| `forwarding_unit.v` | `cpu_tb` | **100.00%** | **100.00%** | **100.00%** | **100.00%** |
| `hazard_unit.v` | `soc_firmware_tb` | **100.00%** | **100.00%** | **33.33%** | **80.00%** |
| `icache.v` | `icache_tb` | **98.36%** | **92.31%** | **100.00%** | **0.79%** |
| `imm_gen.v` | `cpu_tb` | **100.00%** | **100.00%** | **0.00%** | **100.00%** |
| `multiplier.v` | `cpu_tb` | **100.00%** | **100.00%** | **0.00%** | **90.37%** |
| `pipeline_registers.v` | `cpu_tb` | **97.28%** | **93.75%** | **0.00%** | **75.16%** |
| `register_file.v` | `cpu_tb` | **100.00%** | **100.00%** | **100.00%** | **0.00%** |
| `soc_top.v` | `soc_tb` | **98.28%** | **77.27%** | **0.00%** | **20.48%** |
