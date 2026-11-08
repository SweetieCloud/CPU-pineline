#include "uart.h"
#include "soc_regs.h"

void uart_init(uint32_t baud_div) {
    if (baud_div != 0) {
        UART_BAUD_REG = baud_div;
    }
}

void uart_putc(char c) {
    // Chờ cho đến khi bộ truyền TX sẵn sàng (Bit 1 = 1)
    while (!(UART_STAT_REG & UART_STAT_TX_READY));
    UART_DATA_REG = (uint32_t)(uint8_t)c;
}

void uart_puts(const char *s) {
    while (*s) {
        if (*s == '\n') {
            uart_putc('\r');
        }
        uart_putc(*s++);
    }
}

void uart_print_hex(uint32_t val) {
    const char hex_chars[] = "0123456789ABCDEF";
    uart_puts("0x");
    for (int i = 7; i >= 0; i--) {
        uint8_t nibble = (val >> (i * 4)) & 0x0F;
        uart_putc(hex_chars[nibble]);
    }
}

void uart_print_dec(uint32_t val) {
    if (val == 0) {
        uart_putc('0');
        return;
    }
    char buf[12];
    int idx = 0;
    while (val > 0) {
        buf[idx++] = '0' + (val % 10);
        val /= 10;
    }
    for (int i = idx - 1; i >= 0; i--) {
        uart_putc(buf[i]);
    }
}

int uart_has_rx(void) {
    return (UART_STAT_REG & UART_STAT_RX_VALID) ? 1 : 0;
}

char uart_getc(void) {
    while (!uart_has_rx());
    return (char)(UART_DATA_REG & 0xFF);
}
