# =============================================================================
# VIVADO BATCH IMPLEMENTATION & BITSTREAM GENERATION SCRIPT
# Target Board: Digilent Arty Z7-20 (xc7z020clg400-1)
# Top Module: soc_top_arty_z7
# =============================================================================

set project_dir "C:/Users/BuiThanhQui/CPU-pineline/vivado"
set part_name   "xc7z020clg400-1"
set top_module  "soc_top_arty_z7"

cd $project_dir
puts "===> Starting Implementation for $top_module on $part_name in $project_dir"

# 1. Read Verilog RTL Sources
set rtl_files [list \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/alu.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/control_unit.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/register_file.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/forwarding_unit.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/hazard_unit.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/pipeline_registers.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/branch_comp.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/imm_gen.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/branch_predictor.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/multiplier.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/divider.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/csr_file.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/datapath.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/icache.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_i.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_lite_master_d.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new/cpu_top.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_interconnect.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_uart_lite.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_gpio.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/axi_timer.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/soc_top.v" \
    "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new/soc_top_arty_z7.v" \
]

foreach file $rtl_files {
    read_verilog $file
}

# 2. Read Physical and Timing Constraints
read_xdc "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/constrs_1/new/arty_z7_20.xdc"

# 3. Run Synthesis
puts "===> (STAGE 1/5) Running Synthesis..."
synth_design -top $top_module -part $part_name -include_dirs [list "C:/Users/BuiThanhQui/CPU-pineline/vivado/vivado.srcs/sources_1/new" "C:/Users/BuiThanhQui/CPU-pineline/cpu_pipeline.srcs/sources_1/imports/new"]

# Latch Check
set latches [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ CLOCK_ENABLE.latch.* || LIB_CELL =~ "LD*"}]
set latch_count [llength $latches]
puts "--------------------------------------------------"
puts "  LATCH VERIFICATION AUDIT:"
puts "  Total Inferred Latches: $latch_count"
if {$latch_count > 0} {
    puts "  (WARNING) Latches detected: $latches"
} else {
    puts "  (PASS) ZERO LATCHES DETECTED (100% Fully Synchronous RTL)"
}
puts "--------------------------------------------------"

# 4. Logic Optimization
puts "===> (STAGE 2/5) Running Logic Optimization (opt_design)..."
opt_design

# 5. Placement & Physical Optimization
puts "===> (STAGE 3/5) Running Placement (place_design)..."
place_design
puts "===> Running Physical Optimization (phys_opt_design)..."
phys_opt_design

# 6. Routing
puts "===> (STAGE 4/5) Running Routing (route_design)..."
route_design

# 7. Generate Quality Reports
puts "===> Generating Implementation Quality Reports..."
file mkdir "reports"
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -routable_nets -file "reports/timing_summary.rpt"
report_utilization -file "reports/utilization.rpt"
report_utilization -hierarchical -file "reports/utilization_hierarchical.rpt"
report_clock_utilization -file "reports/clock_utilization.rpt"
report_drc -file "reports/drc.rpt"
report_power -file "reports/power.rpt"

# 8. Bitstream Generation
puts "===> (STAGE 5/5) Generating Bitstream..."
write_bitstream -force "soc_top_arty_z7.bit"

puts "================================================================="
puts "   PHYSICAL IMPLEMENTATION & BITSTREAM GENERATION COMPLETE!"
puts "   Output Bitstream: $project_dir/soc_top_arty_z7.bit"
puts "   Timing Report   : $project_dir/reports/timing_summary.rpt"
puts "   Resource Report : $project_dir/reports/utilization.rpt"
puts "================================================================="
exit
