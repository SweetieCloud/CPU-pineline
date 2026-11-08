# =============================================================================
# AUTOMATED FPGA PROGRAMMING SCRIPT FOR DIGILENT ARTY Z7-20
# =============================================================================
puts "===> Connecting to Vivado Hardware Server..."
open_hw_manager

# Connect to local hardware server (start if not already running)
if {[catch {connect_hw_server -allow_non_jtag} err]} {
    puts "ERROR connecting to hw_server: $err"
    exit 1
}

# Open target
if {[catch {open_hw_target} err]} {
    puts "ERROR opening hw_target: $err"
    puts "Vui long kiem tra:"
    puts " 1. Cap Micro-USB da cam chac vao cong PROG/UART (J14) cua kit Arty Z7-20."
    puts " 2. Cong tac nguon (Power Switch) cua kit da bat (LED nguon sang)."
    puts " 3. Driver Digilent Adept / JTAG da duoc nhan trong Device Manager."
    close_hw_manager
    exit 1
}

set dev_list [get_hw_devices]
puts "===> Found JTAG Chain Devices: $dev_list"

# Find xc7z020 target device
set fpga_dev [get_hw_devices -filter {NAME =~ "*xc7z020*" || PART =~ "xc7z020*"}]
if {[llength $fpga_dev] == 0} {
    # Fallback to second device if 2 exist (Zynq index 0: arm_dap, index 1: xc7z020)
    if {[llength $dev_list] >= 2} {
        set fpga_dev [lindex $dev_list 1]
    } else {
        set fpga_dev [lindex $dev_list 0]
    }
}

puts "===> Programming Target Device: $fpga_dev"
current_hw_device $fpga_dev
refresh_hw_device -update_hw_probes false $fpga_dev

set bitfile "soc_top_arty_z7.bit"
if {![file exists $bitfile]} {
    puts "ERROR: File $bitfile khong ton tai trong thu muc hien tai!"
    exit 1
}

set_property PROGRAM.FILE $bitfile $fpga_dev
puts "===> Flashing $bitfile into FPGA..."
program_hw_devices $fpga_dev
refresh_hw_device $fpga_dev

puts "================================================================="
puts "   (SUCCESS) NAP BITSTREAM LEN KIT ARTY Z7-20 THANH CONG!"
puts "   Den DONE tren kit se sang len."
puts "================================================================="

close_hw_target
disconnect_hw_server
close_hw_manager
exit 0
