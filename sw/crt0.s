# ==============================================================================
# RISC-V RV32IM BARE-METAL C-RUNTIME STARTUP CODE (crt0.s)
# ==============================================================================
# - Thiet lap con tro ngan xep Stack Pointer (sp = 0x00003FFC)
# - Thiet lap con tro toan cuc Global Pointer (gp)
# - Xoa toan bo phan vung .bss ve 0
# - Goi ham main() trong C
# - Phat ECALL va dung CPU an toan khi ket thuc
# ==============================================================================

.section .text.init
.global _start
.type _start, @function

_start:
    # 1. Khởi tạo Global Pointer (gp) và Stack Pointer (sp)
    .option push
    .option norelax
    la      gp, __global_pointer$
    .option pop
    la      sp, __stack_top

    # 2. Xóa vùng nhớ .bss về 0 (BSS Zeroing)
    la      a0, __bss_start
    la      a1, __bss_end
    bgeu    a0, a1, .L_bss_done

.L_bss_loop:
    sw      zero, 0(a0)
    addi    a0, a0, 4
    bltu    a0, a1, .L_bss_loop

.L_bss_done:
    # 3. Gọi hàm main() trong chương trình C
    call    main

    # 4. Khi main() kết thúc, phát ECALL dừng mô phỏng
.L_exit:
    ecall
    j       .L_exit

.size _start, . - _start
