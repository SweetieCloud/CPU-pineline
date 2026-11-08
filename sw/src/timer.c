#include "timer.h"
#include "soc_regs.h"

void timer_init(void) {
    // Kich hoat bo dem Machine Timer (Bit 0 = 1)
    TIMER_CTRL_REG = 0x01;
}

uint64_t timer_get_time(void) {
    uint32_t high1, low, high2;
    // Chế độ đọc nguyên tử 64-bit chống tràn giữa low và high
    do {
        high1 = MTIME_HIGH_REG;
        low   = MTIME_LOW_REG;
        high2 = MTIME_HIGH_REG;
    } while (high1 != high2);
    return (((uint64_t)high1) << 32) | (uint64_t)low;
}

uint32_t timer_get_time_low(void) {
    return MTIME_LOW_REG;
}

void timer_delay_ticks(uint32_t ticks) {
    uint32_t start = MTIME_LOW_REG;
    while ((MTIME_LOW_REG - start) < ticks);
}

void timer_delay_ms(uint32_t ms) {
    // Với xung nhịp 50 MHz -> 50,000 xung nhịp ứng với 1 ms
    timer_delay_ticks(ms * 50000);
}
