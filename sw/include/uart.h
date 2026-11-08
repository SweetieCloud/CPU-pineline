#ifndef UART_H
#define UART_H

#include <stdint.h>

// Khoi tao UART voi ti le chia Baud Divisor
void uart_init(uint32_t baud_div);

// Xuat mot ky tu ra UART
void uart_putc(char c);

// Xuat chuoi ky tu ra UART (tu dong chuyen \n thanh \r\n)
void uart_puts(const char *s);

// In gia tri so nguyen 32-bit dang Hex (0x12345678)
void uart_print_hex(uint32_t val);

// In gia tri so nguyen khong dau dang Dec (12345)
void uart_print_dec(uint32_t val);

// Kiem tra co ky tu dang cho trong buffer nhan RX khong
int  uart_has_rx(void);

// Doc mot ky tu tu UART (Block cho toi khi co ky tu)
char uart_getc(void);

#endif // UART_H
