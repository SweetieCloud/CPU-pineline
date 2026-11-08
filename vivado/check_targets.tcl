open_hw_manager
connect_hw_server -allow_non_jtag
set targets [get_hw_targets]
puts "=== TARGETS COUNT: [llength $targets] ==="
puts "=== TARGETS LIST: $targets ==="
close_hw_manager
exit
