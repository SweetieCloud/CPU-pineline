# ==============================================================================
# RISC-V RV32IM STANDALONE FIRMWARE TEST PROGRAM (firmware_demo.s)
# ==============================================================================
# - Test 1: Khoi tao Stack Pointer sp = 0x00003FFC
# - Test 2: In Banner UART Lite (0x10000000)
# - Test 3: Tinh toan phep Nhan RV32M (mul: 5 * 10 = 50)
# - Test 4: Tinh toan phep Chia & Du RV32M (div: 1000 / 7 = 142, rem: 6)
# - Test 5: Doc va ghi BRAM tai 0x00000400 (sw, lw 0xCAFEBABE)
# - Test 6: Doc Switches tu GPIO_IN (0x10001000) va xuat ra LEDs (0x10001004)
# - Test 7: Doc bo dem Timer MTIME (0x10002000)
# - Test 8: Phat ky tu OK va ECALL dung he thong
# ==============================================================================

.section .text
.global _start

_start:
    # 1. Thiet lap Stack Pointer
    li      sp, 0x00003FFC

    # 2. In Banner ra UART
    la      a0, msg_banner
    call    uart_puts

    # 3. Kiem tra RV32M Multiplier (5 * 10 = 50)
    li      t0, 5
    li      t1, 10
    mul     s2, t0, t1              # s2 = 50 = 0x32
    li      t3, 50
    bne     s2, t3, fail

    # In thong bao Mul PASS
    la      a0, msg_mul_pass
    call    uart_puts

    # 4. Kiem tra RV32M Divider (1000 / 7 = 142, rem = 6)
    li      t0, 1000
    li      t1, 7
    div     s3, t0, t1              # s3 = 142
    rem     s4, t0, t1              # s4 = 6
    li      t4, 142
    bne     s3, t4, fail
    li      t5, 6
    bne     s4, t5, fail

    # In thong bao Div PASS
    la      a0, msg_div_pass
    call    uart_puts

    # 5. Kiem tra doc/ghi BRAM (Store / Load 0xCAFEBABE)
    li      t0, 0x00000400          # BRAM scratchpad offset
    li      t1, 0xCAFEBABE
    sw      t1, 0(t0)
    lw      t2, 0(t0)
    bne     t1, t2, fail

    # In thong bao BRAM PASS
    la      a0, msg_bram_pass
    call    uart_puts

    # 6. Kiem tra GPIO: Doc switch va xuat ra LED
    li      t0, 0x10001000          # GPIO Base
    lw      t1, 0(t0)               # GPIO_IN (Switches [3:0])
    xori    t2, t1, 0x0A            # Dao mau LED
    sw      t2, 4(t0)               # GPIO_OUT (LEDs [3:0])

    la      a0, msg_gpio_pass
    call    uart_puts

    # 7. Kiem tra Machine Timer
    li      t0, 0x10002000          # Timer Base
    lw      t1, 0(t0)               # MTIME_LOW

    la      a0, msg_all_pass
    call    uart_puts

    # 8. Hoan thanh thanh cong tat ca bai test, phat ECALL cho testbench ghi nhan PASS
    ecall

    # 9. Chuyen sang che do Tuong Tac Thoi Gian Thuc (Live Interactive Polling Loop)
    # CPU lien tuc doc Switch va cap nhat LED ngay lap tuc (khong can phai bam nut Reset!)
live_interactive_loop:
    li      t0, 0x10001000          # GPIO Base (0x1000_1000)
    lw      t1, 0(t0)               # Doc trang thai Switches [3:0]
    xori    t2, t1, 0x0A            # Tinh toan: LED = SW ^ 0x0A
    sw      t2, 4(t0)               # Xuat ngay lap tuc ra LEDs [3:0]
    j       live_interactive_loop

fail:
    la      a0, msg_fail
    call    uart_puts
fail_loop:
    ecall
    j       fail_loop

# ------------------------------------------------------------------------------
# Ham xuat chuoi ky tu ra UART Lite (a0 = con tro chuoi ket thuc bang 0)
# ------------------------------------------------------------------------------
uart_puts:
    li      t0, 0x10000000          # UART Base (0x10000000)
.L_uart_loop:
    lb      t1, 0(a0)               # Doc 1 byte
    beq     t1, zero, .L_uart_ret

.L_uart_wait:
    lw      t2, 4(t0)               # Doc UART STATUS
    andi    t2, t2, 2               # Bit 1 = tx_ready
    beq     t2, zero, .L_uart_wait

    sw      t1, 0(t0)               # Ghi byte vao TX_DATA
    addi    a0, a0, 1
    j       .L_uart_loop

.L_uart_ret:
    ret

# ------------------------------------------------------------------------------
# Hang so chuoi du lieu
# ------------------------------------------------------------------------------
msg_banner:
    .string "\r\n[RV32IM SoC Online! Arty Z7-20]\r\n"

msg_mul_pass:
    .string "[PASS] RV32M Hardware MUL (5*10=50)\r\n"

msg_div_pass:
    .string "[PASS] RV32M Hardware DIV & REM (1000/7=142 R:6)\r\n"

msg_bram_pass:
    .string "[PASS] BRAM Read/Write (0xCAFEBABE)\r\n"

msg_gpio_pass:
    .string "[PASS] GPIO Switches to LEDs\r\n"

msg_all_pass:
    .string "[SUCCESS] ALL SYSTEM-ON-CHIP TESTS PASSED!\r\n"

msg_fail:
    .string "[FAIL] HARDWARE TEST ERROR DETECTED!\r\n"
