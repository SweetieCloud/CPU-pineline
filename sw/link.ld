/* =============================================================================
   LINKER SCRIPT FOR RV32IM INDUSTRIAL SOC (16KB BRAM)
   =============================================================================
   - BRAM Architecture: True Dual-Port 16KB (4096 words x 32-bit)
   - Address Space: 0x0000_0000 - 0x0000_3FFF
   - Stack Top: 0x0000_3FFC (Grows downwards)
   - MMIO Boundary: BRAM ends at 0x0000_3FFF; Peripherals start at 0x1000_0000
   ============================================================================= */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    /* 16KB Dual-Port BRAM */
    BRAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    /* Vùng chứa mã lệnh thực thi và hằng số chuỗi (Read-Only) */
    .text : {
        . = ALIGN(4);
        *(.text.init)
        *(.text .text.*)
        *(.rodata .rodata.*)
        . = ALIGN(4);
        _etext = .;
    } > BRAM

    /* Vùng dữ liệu khởi tạo (Data) */
    .data : {
        . = ALIGN(4);
        __data_start = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        __data_end = .;
    } > BRAM

    /* Vùng dữ liệu chưa khởi tạo (BSS) */
    .bss : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > BRAM

    /* Đỉnh ngăn xếp Stack Pointer đặt tại đỉnh của BRAM 16KB */
    . = ALIGN(4);
    _end = .;
    PROVIDE(__global_pointer$ = __bss_start + 0x800);
    PROVIDE(__stack_top = ORIGIN(BRAM) + LENGTH(BRAM) - 4); /* 0x00003FFC */
}
