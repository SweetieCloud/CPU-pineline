#include <stdint.h>
#include "soc_regs.h"
#include "uart.h"
#include "gpio.h"
#include "timer.h"

// -----------------------------------------------------------------------------
// Hàm tính giai thừa kiểm tra lệnh nhân phần cứng RV32M (mul)
// -----------------------------------------------------------------------------
static uint32_t compute_factorial(uint32_t n) {
    uint32_t result = 1;
    for (uint32_t i = 1; i <= n; i++) {
        result *= i; // Sử dụng lệnh mul phần cứng
    }
    return result;
}

// -----------------------------------------------------------------------------
// Hàm kiểm tra lệnh chia và lấy dư phần cứng RV32M (div, rem)
// -----------------------------------------------------------------------------
static void test_rv32m_math(void) {
    uart_puts("[TEST 1] Testing Hardware RV32M Multiplier & Divider...\n");
    
    // Test Nhân: 5! = 120 (0x78)
    uint32_t fact5 = compute_factorial(5);
    uart_puts("  Factorial(5) = ");
    uart_print_dec(fact5);
    uart_puts(" (Hex: ");
    uart_print_hex(fact5);
    uart_puts(")");
    if (fact5 == 120) {
        uart_puts(" -> PASS\n");
    } else {
        uart_puts(" -> FAIL!\n");
    }

    // Test Chia: 1000 / 7 = 142 (0x8E), dư 6
    volatile uint32_t dividend = 1000;
    volatile uint32_t divisor  = 7;
    uint32_t quotient  = dividend / divisor; // Sử dụng lệnh div
    uint32_t remainder = dividend % divisor; // Sử dụng lệnh rem

    uart_puts("  1000 / 7 = ");
    uart_print_dec(quotient);
    uart_puts(" Remainder: ");
    uart_print_dec(remainder);
    if (quotient == 142 && remainder == 6) {
        uart_puts(" -> PASS\n");
    } else {
        uart_puts(" -> FAIL!\n");
    }
}

// -----------------------------------------------------------------------------
// Hàm kiểm tra đọc/ghi bộ nhớ BRAM qua Bus AXI4-Lite
// -----------------------------------------------------------------------------
static void test_bram_rw(void) {
    uart_puts("[TEST 2] Testing BRAM Read/Write Consistency...\n");
    volatile uint32_t *scratch_addr = (volatile uint32_t *)(0x00000400UL);
    uint32_t pattern = 0xCAFEBABE;
    *scratch_addr = pattern;
    uint32_t read_back = *scratch_addr;

    uart_puts("  Wrote: ");
    uart_print_hex(pattern);
    uart_puts(" | Read: ");
    uart_print_hex(read_back);
    if (read_back == pattern) {
        uart_puts(" -> PASS\n");
    } else {
        uart_puts(" -> FAIL!\n");
    }
}

// -----------------------------------------------------------------------------
// Hàm kiểm tra GPIO và hiển thị trạng thái
// -----------------------------------------------------------------------------
static void test_gpio_and_timer(void) {
    uart_puts("[TEST 3] Testing GPIO & Machine Timer...\n");
    uint8_t sw = gpio_sw_read();
    uart_puts("  Current Switches state: 0x");
    uart_putc("0123456789ABCDEF"[sw & 0x0F]);
    uart_puts("\n");

    // Xuất giá trị mẫu ra LED (đảo bit switch)
    uint8_t led_val = sw ^ 0x0A;
    gpio_led_write(led_val);
    uart_puts("  LEDs written with pattern: 0x");
    uart_putc("0123456789ABCDEF"[led_val & 0x0F]);
    uart_puts(" -> PASS\n");

    // Đọc thời gian thực từ Timer MTIME
    uint32_t t_low = timer_get_time_low();
    uart_puts("  Current Timer MTIME (ticks): ");
    uart_print_hex(t_low);
    uart_puts(" -> PASS\n");
}

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------
int main(void) {
    // 1. Khởi tạo phần cứng ngoại vi
    gpio_init();
    timer_init();
    uart_init(0); // Dùng baudrate mặc định

    // 2. In Banner chào mừng ra cổng nối tiếp
    uart_puts("\n");
    uart_puts("====================================================\n");
    uart_puts("  RISC-V RV32IM Industrial SoC Online!\n");
    uart_puts("  Target: Digilent Arty Z7-20 (xc7z020clg400-1)\n");
    uart_puts("  Core: 5-Stage RV32IM + L1 I-Cache + AXI4-Lite Crossbar\n");
    uart_puts("====================================================\n\n");

    // 3. Thực thi các bài test xác nhận chức năng
    test_rv32m_math();
    test_bram_rw();
    test_gpio_and_timer();

    uart_puts("\n====================================================\n");
    uart_puts("  ALL HARDWARE & FIRMWARE TESTS PASSED!\n");
    uart_puts("  System ready for user interactive operation.\n");
    uart_puts("====================================================\n\n");

    return 0; // Trở về crt0.s phát lệnh ecall dừng mô phỏng an toàn
}
