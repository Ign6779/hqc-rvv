#define VSETVLI_E8_M1(rd, rs1)   .insn i 0x57, 0x7, rd, rs1, 0
#define VSETVLI_E16_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 4
#define VSETVLI_E32_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 8
#define VSETVLI_E64_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 12

#define TOOM_WORDS          94
#define EVAL_WORDS          96
#define U2_REAL_WORDS       89
#define TMP_WORDS           565
#define LAST_WORD_MASK      0x1f

.macro ZERO_WORDS ptr_reg, nwords
    li t0, \nwords
.L_zero_loop\@:
    beqz t0, .L_zero_done\@
    VSETVLI_E64_M1(t1, t0)
    vmv.v.i v0, 0
    vse64.v v0, (\ptr_reg)
    slli t2, t1, 3
    add \ptr_reg, \ptr_reg, t2
    sub t0, t0, t1
    j .L_zero_loop\@
.L_zero_done\@:
.endm

.macro COPY_WORDS dst_reg, src_reg, nwords
    li t0, \nwords
.L_copy_loop\@:
    beqz t0, .L_copy_done\@
    VSETVLI_E64_M1(t1, t0)
    vle64.v v0, (\src_reg)
    vse64.v v0, (\dst_reg)
    slli t2, t1, 3
    add \src_reg, \src_reg, t2
    add \dst_reg, \dst_reg, t2
    sub t0, t0, t1
    j .L_copy_loop\@
.L_copy_done\@:
.endm

    .section .bss
    .align 3

U0:
    .zero EVAL_WORDS * 8
U1:
    .zero EVAL_WORDS * 8
U2:
    .zero EVAL_WORDS * 8

V0:
    .zero EVAL_WORDS * 8
V1:
    .zero EVAL_WORDS * 8
V2:
    .zero EVAL_WORDS * 8

    .text
    .globl rvv_toom3_mul
    .type rvv_toom3_mul, @function

rvv_toom3_mul:
# CLEANING SQUAD
    mv t3, a0
    ZERO_WORDS t3, TMP_WORDS

    la t3, U0
    ZERO_WORDS t3, EVAL_WORDS

    la t3, U1
    ZERO_WORDS t3, EVAL_WORDS

    la t3, U2
    ZERO_WORDS t3, EVAL_WORDS

    la t3, V0
    ZERO_WORDS t3, EVAL_WORDS

    la t3, V1
    ZERO_WORDS t3, EVAL_WORDS

    la t3, V2
    ZERO_WORDS t3, EVAL_WORDS

# TOOM3 SPLIT
    # U0 = A + 0 * TOOM_WORDS
    la t3, U0
    mv t4, a1
    COPY_WORDS t3, t4, TOOM_WORDS

    # U1 = A + 1 * TOOM_WORDS
    la t3, U1
    mv t4, a1
    addi t4, t4, TOOM_WORDS * 8
    COPY_WORDS t3, t4, TOOM_WORDS

    # U2 = A + 2 * TOOM_WORDS
    # Only copy the real input words. Do not read padded words from A.
    la t3, U2
    mv t4, a1
    addi t4, t4, (2 * TOOM_WORDS) * 8
    COPY_WORDS t3, t4, U2_REAL_WORDS

    # Mask unused high bits of final real word in U2.
    la t3, U2
    ld t4, 88 * 8(t3)
    li t5, LAST_WORD_MASK
    and t4, t4, t5
    sd t4, 88 * 8(t3)

    # V0 = B + 0 * TOOM_WORDS
    la t3, V0
    mv t4, a2
    COPY_WORDS t3, t4, TOOM_WORDS

    # V1 = B + 1 * TOOM_WORDS
    la t3, V1
    mv t4, a2
    addi t4, t4, TOOM_WORDS * 8
    COPY_WORDS t3, t4, TOOM_WORDS

    # V2 = B + 2 * TOOM_WORDS
    # Only copy the real input words. Do not read padded words from B.
    la t3, V2
    mv t4, a2
    addi t4, t4, (2 * TOOM_WORDS) * 8
    COPY_WORDS t3, t4, U2_REAL_WORDS

    # Mask unused high bits of final real word in V2.
    la t3, V2
    ld t4, 88 * 8(t3)
    li t5, LAST_WORD_MASK
    and t4, t4, t5
    sd t4, 88 * 8(t3)

    # multiplication here or whatever
    # write to output
    # WIPE BUFFERS

    ret

    .size rvv_toom3_mul, .-rvv_toom3_mul