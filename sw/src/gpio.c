#include "gpio.h"
#include "soc_regs.h"

void gpio_init(void) {
    // 4 bit thap [3:0] la dau ra LED, cac bit con lai la dau vao
    GPIO_DIR_REG = 0x0F;
}

void gpio_led_write(uint8_t val) {
    GPIO_OUT_REG = (uint32_t)(val & 0x0F);
}

uint8_t gpio_sw_read(void) {
    // Bit [3:0] la gia tri cac Switch
    return (uint8_t)(GPIO_IN_REG & 0x0F);
}

uint8_t gpio_btn_read(void) {
    // Bit [7:4] la gia tri cac Button
    return (uint8_t)((GPIO_IN_REG >> 4) & 0x0F);
}
