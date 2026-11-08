#ifndef SOC_REGS_H
#define SOC_REGS_H

#include <stdint.h>

// =============================================================================
// RV32IM SYSTEM-ON-CHIP MEMORY-MAPPED REGISTERS DEFINITIONS
// =============================================================================

#define REG32(addr) (*(volatile uint32_t *)(addr))

// Base Addresses mapped by AMBA AXI4-Lite Crossbar Interconnect
#define BRAM_BASE          0x00000000UL // 0x0000_0000 - 0x0000_3FFF (16KB)
#define UART_BASE          0x10000000UL // 0x1000_0000 - 0x1000_0FFF (UART Lite)
#define GPIO_BASE          0x10001000UL // 0x1000_1000 - 0x1000_1FFF (GPIO)
#define TIMER_BASE         0x10002000UL // 0x1000_2000 - 0x1000_2FFF (MTIME Timer)

// -----------------------------------------------------------------------------
// 1. UART Lite Registers (115200 Baud, 8-N-1)
// -----------------------------------------------------------------------------
#define UART_DATA_REG      REG32(UART_BASE + 0x00) // W: TX Data / R: RX Data
#define UART_STAT_REG      REG32(UART_BASE + 0x04) // R: Status Register
#define UART_BAUD_REG      REG32(UART_BASE + 0x08) // R/W: Baud Divisor

#define UART_STAT_RX_VALID (1U << 0) // Bit 0: Co byte hop le trong buffer RX
#define UART_STAT_TX_READY (1U << 1) // Bit 1: TX san sang nhan byte moi
#define UART_STAT_TX_BUSY  (1U << 2) // Bit 2: TX dang truyen bit tren duong truyen

// -----------------------------------------------------------------------------
// 2. GPIO Registers (Arty Z7-20 4 LEDs, 4 Switches, 4 Buttons)
// -----------------------------------------------------------------------------
#define GPIO_IN_REG        REG32(GPIO_BASE + 0x00) // R: [3:0]=Switches, [7:4]=Buttons
#define GPIO_OUT_REG       REG32(GPIO_BASE + 0x04) // R/W: [3:0]=LEDs
#define GPIO_DIR_REG       REG32(GPIO_BASE + 0x08) // R/W: Direction (1=Out, 0=In)

// -----------------------------------------------------------------------------
// 3. RISC-V Machine Timer Registers (64-bit Real-time Counter)
// -----------------------------------------------------------------------------
#define MTIME_LOW_REG      REG32(TIMER_BASE + 0x00) // R/W: mtime[31:0]
#define MTIME_HIGH_REG     REG32(TIMER_BASE + 0x04) // R/W: mtime[63:32]
#define MTIMECMP_LOW_REG   REG32(TIMER_BASE + 0x08) // R/W: mtimecmp[31:0]
#define MTIMECMP_HIGH_REG  REG32(TIMER_BASE + 0x0C) // R/W: mtimecmp[63:32]
#define TIMER_CTRL_REG     REG32(TIMER_BASE + 0x10) // R/W: [0]=Timer En, [1]=IRQ En

#endif // SOC_REGS_H
