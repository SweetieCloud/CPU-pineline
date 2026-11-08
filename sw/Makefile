# ==============================================================================
# MAKEFILE FOR RV32IM BARE-METAL FIRMWARE COMPILATION
# ==============================================================================

CROSS_COMPILE ?= riscv32-unknown-elf-
CC             = $(CROSS_COMPILE)gcc
AS             = $(CROSS_COMPILE)as
LD             = $(CROSS_COMPILE)ld
OBJCOPY        = $(CROSS_COMPILE)objcopy
OBJDUMP        = $(CROSS_COMPILE)objdump

CFLAGS         = -march=rv32im -mabi=ilp32 -O2 -Wall -Wextra -ffreestanding -nostdlib -Iinclude
LDFLAGS        = -T link.ld -nostdlib

SRCS_C         = src/main.c src/uart.c src/gpio.c src/timer.c
SRCS_S         = crt0.s
OBJS           = $(SRCS_S:.s=.o) $(SRCS_C:.c=.o)

TARGET         = firmware

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).dump

%.o: %.s
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) link.ld
	$(CC) $(CFLAGS) $(LDFLAGS) $(OBJS) -o $@

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).bin
	python ../tools/bin2hex.py $< $@

$(TARGET).dump: $(TARGET).elf
	$(OBJDUMP) -D -S $< > $@

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).dump

.PHONY: all clean
