#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

// Khoi dong bo dem Timer MTIME
void     timer_init(void);

// Doc gia tri bo dem 64-bit mtime chong roll-over hazard
uint64_t timer_get_time(void);

// Doc gia tri 32-bit thap cua mtime
uint32_t timer_get_time_low(void);

// Tao tre theo so chu ky xung nhip
void     timer_delay_ticks(uint32_t ticks);

// Tao tre theo mili-giay (ms) dua tren tan so xung nhip 50MHz
void     timer_delay_ms(uint32_t ms);

#endif // TIMER_H
