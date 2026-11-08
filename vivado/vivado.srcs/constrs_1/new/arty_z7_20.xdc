## =============================================================================
## PHYSICAL PIN & TIMING CONSTRAINTS FOR DIGILENT ARTY Z7-20 (xc7z020clg400-1)
## =============================================================================

## 1. Master Input Clock (125 MHz Oscillator on Pin H16)
set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { i_clk_125mhz }];
create_clock -add -name sys_clk_pin -period 8.000 -waveform {0.000 4.000} [get_ports { i_clk_125mhz }];

## 2. Reset Button (BTN0 - Pin D19, Active-High)
set_property -dict { PACKAGE_PIN D19   IOSTANDARD LVCMOS33 } [get_ports { i_btn0_rst }];

## 3. User Slide Switches (2 switches on Arty Z7-20)
set_property -dict { PACKAGE_PIN M20   IOSTANDARD LVCMOS33 } [get_ports { i_sw[0] }];
set_property -dict { PACKAGE_PIN M19   IOSTANDARD LVCMOS33 } [get_ports { i_sw[1] }];

## 4. User Push Buttons (BTN1, BTN2, BTN3)
set_property -dict { PACKAGE_PIN D20   IOSTANDARD LVCMOS33 } [get_ports { i_btn_user[0] }];
set_property -dict { PACKAGE_PIN L20   IOSTANDARD LVCMOS33 } [get_ports { i_btn_user[1] }];
set_property -dict { PACKAGE_PIN L19   IOSTANDARD LVCMOS33 } [get_ports { i_btn_user[2] }];

## 5. User Monochromatic LEDs (4 LEDs)
set_property -dict { PACKAGE_PIN R14   IOSTANDARD LVCMOS33 } [get_ports { o_led[0] }];
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { o_led[1] }];
set_property -dict { PACKAGE_PIN N16   IOSTANDARD LVCMOS33 } [get_ports { o_led[2] }];
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { o_led[3] }];

## 6. Primary UART Serial Interface (ChipKit Digital IO0 / IO1)
set_property -dict { PACKAGE_PIN U12   IOSTANDARD LVCMOS33 } [get_ports { o_uart_tx }];
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS33 } [get_ports { i_uart_rx }];

## 7. Secondary UART Mirror (Pmod JA Pin 1 & Pin 2)
set_property -dict { PACKAGE_PIN Y18   IOSTANDARD LVCMOS33 } [get_ports { o_pmod_tx }];
set_property -dict { PACKAGE_PIN Y19   IOSTANDARD LVCMOS33 } [get_ports { i_pmod_rx }];

## 8. False Path Constraints for Asynchronous Inputs
set_false_path -from [get_ports { i_btn0_rst }]
set_false_path -from [get_ports { i_sw[*] }]
set_false_path -from [get_ports { i_btn_user[*] }]
set_false_path -from [get_ports { i_uart_rx }]
set_false_path -from [get_ports { i_pmod_rx }]
set_false_path -to   [get_ports { o_led[*] }]

## 9. Configuration & Bitstream Settings
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
