#ifndef GPIO_H
#define GPIO_H

#include <stdint.h>

// Khoi tao huong xuat nhap GPIO
void    gpio_init(void);

// Xuat gia tri ra 4 den LED (Arty Z7-20: LD0 - LD3)
void    gpio_led_write(uint8_t val);

// Doc trang thai 4 cong tac gat (Arty Z7-20: SW0 - SW3)
uint8_t gpio_sw_read(void);

// Doc trang thai 4 nut bam (Arty Z7-20: BTN0 - BTN3)
uint8_t gpio_btn_read(void);

#endif // GPIO_H
