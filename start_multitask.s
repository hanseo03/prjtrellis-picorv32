# ============================================================
# start_multitask.s  --  PicoRV32 multitask startup
#
# Memory layout:
#   0x0000 : reset vector  (j _start_main)
#   0x0010 : IRQ vector    (context switch + schedule())
#   0x0020+: code
#
# Context frame on stack (132 bytes = 33 words):
#   offset   0 : PC  (return address saved in q0 by hardware)
#   offset   4 : x1  (ra)
#   offset   8 : x2  (sp, value BEFORE addi sp,-132)
#   offset  12 : x3  (gp)
#   offset  16 : x4  (tp)
#   offset  20 : x5  (t0)
#   ...
#   offset 128 : x31 (t6)
#
# Custom instruction encodings (.word):
#   getq ra, q0  = 0x0000008B   (q0  -> ra)
#   getq ra, q1  = 0x0000808B   (q1  -> ra)
#   setq q0, a0  = 0x0205000B   (a0  -> q0)
#   setq q1, ra  = 0x0200808B   (ra  -> q1)
#   retirq       = 0x0400000B   (jump to q0, re-enable IRQ)
#   maskirq a0,a0= 0x0605050B
# ============================================================

.section .text.init, "ax", @progbits
.global _start

# ----------------------------------------------------------
# 0x0000: reset vector
# ----------------------------------------------------------
_start:
    j _start_main

# ----------------------------------------------------------
# 0x0010: IRQ vector  (PROGADDR_IRQ = 0x00000010)
# ----------------------------------------------------------
    .balign 16, 0x13

irq_vec:
    # 1. Backup ra to q1
    .word 0x0200808B            # setq q1, ra

    # 2. Allocate context frame (33 words = 132 bytes)
    addi  sp, sp, -132

    # 3. Save return PC (q0) via ra -> frame[0]
    .word 0x0000008B            # getq ra, q0
    sw    ra,   0(sp)

    # 4. Restore original ra from q1 -> frame[1]
    .word 0x0000808B            # getq ra, q1
    sw    x1,   4(sp)

    # 5. Save original sp (= current sp + 132) -> frame[2]
    addi  ra, sp, 132
    sw    ra,   8(sp)

    # 6. Save x3-x31
    sw    x3,  12(sp)
    sw    x4,  16(sp)
    sw    x5,  20(sp)
    sw    x6,  24(sp)
    sw    x7,  28(sp)
    sw    x8,  32(sp)
    sw    x9,  36(sp)
    sw    x10, 40(sp)
    sw    x11, 44(sp)
    sw    x12, 48(sp)
    sw    x13, 52(sp)
    sw    x14, 56(sp)
    sw    x15, 60(sp)
    sw    x16, 64(sp)
    sw    x17, 68(sp)
    sw    x18, 72(sp)
    sw    x19, 76(sp)
    sw    x20, 80(sp)
    sw    x21, 84(sp)
    sw    x22, 88(sp)
    sw    x23, 92(sp)
    sw    x24, 96(sp)
    sw    x25,100(sp)
    sw    x26,104(sp)
    sw    x27,108(sp)
    sw    x28,112(sp)
    sw    x29,116(sp)
    sw    x30,120(sp)
    sw    x31,124(sp)

    # 7. Call schedule(current_sp) -> new_sp (a0)
    mv    a0, sp
    jal   ra, schedule
    mv    sp, a0                # sp = new task's context frame

    # 8. Set q0 to new task's PC
    lw    a0, 0(sp)
    .word 0x0205000B            # setq q0, a0

    # 9. Restore x1-x31 (x2/sp restored last)
    lw    x1,   4(sp)
    lw    x3,  12(sp)
    lw    x4,  16(sp)
    lw    x5,  20(sp)
    lw    x6,  24(sp)
    lw    x7,  28(sp)
    lw    x8,  32(sp)
    lw    x9,  36(sp)
    lw    x10, 40(sp)
    lw    x11, 44(sp)
    lw    x12, 48(sp)
    lw    x13, 52(sp)
    lw    x14, 56(sp)
    lw    x15, 60(sp)
    lw    x16, 64(sp)
    lw    x17, 68(sp)
    lw    x18, 72(sp)
    lw    x19, 76(sp)
    lw    x20, 80(sp)
    lw    x21, 84(sp)
    lw    x22, 88(sp)
    lw    x23, 92(sp)
    lw    x24, 96(sp)
    lw    x25,100(sp)
    lw    x26,104(sp)
    lw    x27,108(sp)
    lw    x28,112(sp)
    lw    x29,116(sp)
    lw    x30,120(sp)
    lw    x31,124(sp)
    lw    x2,   8(sp)           # restore sp last

    .word 0x0400000B            # retirq -> jump to q0

# ----------------------------------------------------------
# maskirq(uint32_t mask) -> uint32_t
# ----------------------------------------------------------
.global maskirq
maskirq:
    .word 0x0605050B
    ret

# ----------------------------------------------------------
# start_first_task()
# Load tasks[0].sp and jump into first task via retirq.
# Called once from main after task_init().
# ----------------------------------------------------------
.global start_first_task
start_first_task:
    la    a1, tasks             # a1 = &tasks[0]
    lw    sp, 0(a1)             # sp = tasks[0].sp (context frame)

    lw    a0, 0(sp)
    .word 0x0205000B            # setq q0, a0  (task PC)

    lw    x1,   4(sp)
    lw    x3,  12(sp)
    lw    x4,  16(sp)
    lw    x5,  20(sp)
    lw    x6,  24(sp)
    lw    x7,  28(sp)
    lw    x8,  32(sp)
    lw    x9,  36(sp)
    lw    x10, 40(sp)
    lw    x11, 44(sp)
    lw    x12, 48(sp)
    lw    x13, 52(sp)
    lw    x14, 56(sp)
    lw    x15, 60(sp)
    lw    x16, 64(sp)
    lw    x17, 68(sp)
    lw    x18, 72(sp)
    lw    x19, 76(sp)
    lw    x20, 80(sp)
    lw    x21, 84(sp)
    lw    x22, 88(sp)
    lw    x23, 92(sp)
    lw    x24, 96(sp)
    lw    x25,100(sp)
    lw    x26,104(sp)
    lw    x27,108(sp)
    lw    x28,112(sp)
    lw    x29,116(sp)
    lw    x30,120(sp)
    lw    x31,124(sp)
    lw    x2,   8(sp)           # restore sp last

    .word 0x0400000B            # retirq -> jump to task PC

# ----------------------------------------------------------
# _start_main: firmware entry point
# ----------------------------------------------------------
_start_main:
    li    sp, 0x00008000

    la    t0, _bss_start
    la    t1, _bss_end
_bss_loop:
    bge   t0, t1, _bss_done
    sw    x0, 0(t0)
    addi  t0, t0, 4
    j     _bss_loop
_bss_done:
    jal   ra, main

_halt:
    j     _halt
