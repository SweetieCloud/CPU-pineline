`timescale 1ns / 1ps

// =============================================================================
// MODULE: SOC_TOP_ARTY_Z7 - HARDWARE BOARD-LEVEL TOP WRAPPER FOR DIGILENT ARTY Z7-20
// =============================================================================
// Target FPGA: Xilinx Zynq-7000 xc7z020clg400-1 (Arty Z7-20)
// Clocking:
//   - On-board 125.0 MHz Oscillator (Pin H16) -> MMCME2_BASE -> 50.0 MHz Low-Jitter Core Clock
// Reset:
//   - Push Button BTN0 (Pin D19, Active-High) synchronized with MMCM Locked status
// Peripherals:
//   - UART Lite 115200 Baud:
//       * TX routed to ChipKit Digital IO1 (U12) & Pmod JA Pin 1 (Y18)
//       * RX routed from ChipKit Digital IO0 (T14) & Pmod JA Pin 2 (Y19)
//   - 4 User LEDs: Pins R14, P14, N16, M14
//   - 2 User Slide Switches: Pins M20, M19
//   - 3 User Push Buttons: Pins D20, L20, L19
// =============================================================================

module soc_top_arty_z7 #(
    parameter CLK_FREQ_HZ   = 50_000_000,
    parameter BAUD_RATE     = 115_200,
    parameter BOOT_HEX_FILE = "program.hex"
)(
    // 125 MHz Oscillator Input Clock
    input  wire       i_clk_125mhz,

    // Active-High Push Button 0 (System Reset)
    input  wire       i_btn0_rst,

    // User Slide Switches (2 switches on Arty Z7-20)
    input  wire [1:0] i_sw,

    // User Push Buttons (BTN3, BTN2, BTN1)
    input  wire [2:0] i_btn_user,

    // 4 Monochromatic Green User LEDs
    output wire [3:0] o_led,

    // UART Serial Communication
    output wire       o_uart_tx,
    input  wire       i_uart_rx,

    // Pmod JA Mirror (Optional external debug hook)
    output wire       o_pmod_tx,
    input  wire       i_pmod_rx
);

    // =========================================================================
    // 1. CLOCK GENERATION: 125 MHz -> 50 MHz (Xilinx 7-Series MMCME2_BASE)
    // =========================================================================
    // VCO Frequency = (125 MHz * 8) / 1 = 1000 MHz (Within 600 MHz - 1200 MHz spec)
    // CLKOUT0 Frequency = 1000 MHz / 20 = 50.0 MHz
    wire clk_50mhz_unbuf;
    wire clk_50mhz;
    wire clkfb;
    wire mmcm_locked;

    MMCME2_BASE #(
        .BANDWIDTH          ("OPTIMIZED"),
        .CLKFBOUT_MULT_F    (8.000),
        .CLKFBOUT_PHASE     (0.000),
        .CLKIN1_PERIOD      (8.000),      // 125.0 MHz (8.000 ns)
        .CLKOUT0_DIVIDE_F   (20.000),     // 50.0 MHz (1000 / 20)
        .CLKOUT0_DUTY_CYCLE (0.500),
        .CLKOUT0_PHASE      (0.000),
        .DIVCLK_DIVIDE      (1),
        .REF_JITTER1        (0.010),
        .STARTUP_WAIT       ("FALSE")
    ) mmcm_inst (
        .CLKOUT0            (clk_50mhz_unbuf),
        .CLKOUT0B           (),
        .CLKOUT1            (),
        .CLKOUT1B           (),
        .CLKOUT2            (),
        .CLKOUT2B           (),
        .CLKOUT3            (),
        .CLKOUT3B           (),
        .CLKOUT4            (),
        .CLKOUT5            (),
        .CLKOUT6            (),
        .CLKFBOUT           (clkfb),
        .CLKFBOUTB          (),
        .LOCKED             (mmcm_locked),
        .CLKIN1             (i_clk_125mhz),
        .PWRDWN             (1'b0),
        .RST                (1'b0),
        .CLKFBIN            (clkfb)
    );

    BUFG bufg_inst (
        .I                  (clk_50mhz_unbuf),
        .O                  (clk_50mhz)
    );

    // =========================================================================
    // 2. SYNCHRONOUS RESET GENERATOR (Asynchronous Assert, Synchronous Deassert)
    // =========================================================================
    // Active-Low Reset is held LOW while MMCM is not locked or BTN0 is pressed
    wire raw_rst_n = mmcm_locked && (!i_btn0_rst);
    reg [2:0] rst_sync;
    wire soc_rst_n = rst_sync[2];

    always @(posedge clk_50mhz or negedge raw_rst_n) begin
        if (!raw_rst_n) begin
            rst_sync <= 3'b000;
        end else begin
            rst_sync <= {rst_sync[1:0], 1'b1};
        end
    end

    // =========================================================================
    // 3. I/O CONDITIONING & MAPPING
    // =========================================================================
    // Arty Z7-20 has 2 slide switches; map them to lower bits and tie upper bits to 0
    wire [3:0] sw_in  = {2'b00, i_sw[1:0]};
    // BTN0 is dedicated to Reset; map remaining buttons to [3:1]
    wire [3:0] btn_in = {i_btn_user[2:0], 1'b0};

    // UART RX MUX: Allow input from either ChipKit IO0 or Pmod JA Pin 2
    // Idle state for UART RX is 1 (Active-Low start bit)
    wire uart_rx_comb = i_uart_rx & i_pmod_rx;

    // Internal Halt Wire
    wire core_ecall_halt;

    // Mirror UART TX to Pmod JA
    wire uart_tx_out;
    assign o_uart_tx = uart_tx_out;
    assign o_pmod_tx = uart_tx_out;

    // =========================================================================
    // 4. INSTANTIATE RV32IM INDUSTRIAL SYSTEM-ON-CHIP CORE
    // =========================================================================
    soc_top #(
        .ADDR_WIDTH         (32),
        .DATA_WIDTH         (32),
        .CLK_FREQ_HZ        (CLK_FREQ_HZ),
        .BAUD_RATE          (BAUD_RATE),
        .BOOT_HEX_FILE      (BOOT_HEX_FILE)
    ) soc_inst (
        .i_clk              (clk_50mhz),
        .i_rst_n            (soc_rst_n),

        // UART Serial Lines
        .o_uart_tx          (uart_tx_out),
        .i_uart_rx          (uart_rx_comb),

        // Physical kit LEDs & Controls
        .o_led              (o_led),
        .i_sw               (sw_in),
        .i_btn              (btn_in),

        // Debug Status
        .o_ecall_halt       (core_ecall_halt)
    );

endmodule
