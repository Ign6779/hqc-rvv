#define VSETVLI_E8_M1(rd, rs1)   .insn i 0x57, 0x7, rd, rs1, 0
#define VSETVLI_E16_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 4
#define VSETVLI_E32_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 8
#define VSETVLI_E64_M1(rd, rs1)  .insn i 0x57, 0x7, rd, rs1, 12

#define TOOM_WORDS          94
#define EVAL_WORDS          96
#define U2_REAL_WORDS       89
#define TMP_WORDS           565
#define LAST_WORD_MASK      0x1f
#define PROD_WORDS          193

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

.macro XOR3_WORDS dst_reg, src1_reg, src2_reg, src3_reg, nwords
    li t0, \nwords
.L_xor3_loop\@:
    beqz t0, .L_xor3_done\@
    VSETVLI_E64_M1(t1, t0)
    vle64.v v0, (\src1_reg)
    vle64.v v1, (\src2_reg)
    vle64.v v2, (\src3_reg)
    vxor.vv v3, v0, v1
    vxor.vv v3, v3, v2
    vse64.v v3, (\dst_reg)
    slli t2, t1, 3
    add \src1_reg, \src1_reg, t2
    add \src2_reg, \src2_reg, t2
    add \src3_reg, \src3_reg, t2
    add \dst_reg, \dst_reg, t2
    sub t0, t0, t1
    j .L_xor3_loop\@
.L_xor3_done\@:
.endm

.macro XOR_INTO_WORDS dst_reg, src_reg, nwords
    li t0, \nwords
.L_xor_into_loop\@:
    beqz t0, .L_xor_into_done\@
    VSETVLI_E64_M1(t1, t0)
    vle64.v v0, (\dst_reg)
    vle64.v v1, (\src_reg)
    vxor.vv v0, v0, v1
    vse64.v v0, (\dst_reg)
    slli t2, t1, 3
    add \dst_reg, \dst_reg, t2
    add \src_reg, \src_reg, t2
    sub t0, t0, t1
    j .L_xor_into_loop\@
.L_xor_into_done\@:
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

EA:
    .zero EVAL_WORDS * 8 
EB:
    .zero EVAL_WORDS * 8

W0:
    .zero PROD_WORDS * 8
W1:
    .zero PROD_WORDS * 8
W2:
    .zero PROD_WORDS * 8
W3:
    .zero PROD_WORDS * 8
W4:
    .zero PROD_WORDS * 8

    .text
    .extern scalar_mul
    .globl rvv_toom3_mul
    .type rvv_toom3_mul, @function

rvv_toom3_mul:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)

    mv s0, a0

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

    la t3, EA
    ZERO_WORDS t3, EVAL_WORDS

    la t3, EB
    ZERO_WORDS t3, EVAL_WORDS

    la t3, W0
    ZERO_WORDS t3, PROD_WORDS

    la t3, W1
    ZERO_WORDS t3, PROD_WORDS

    la t3, W2
    ZERO_WORDS t3, PROD_WORDS

    la t3, W3
    ZERO_WORDS t3, PROD_WORDS

    la t3, W4
    ZERO_WORDS t3, PROD_WORDS

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

# TOOM3 EVALUATION
    # already have U0, V0
    # W0 = U0 * V0
    la a0, W0
    la a1, U0
    la a2, V0
    li a3, EVAL_WORDS
    call scalar_mul

    # eval at 1
    la t3, EA
    ZERO_WORDS t3, EVAL_WORDS

    la t3, EB
    ZERO_WORDS t3, EVAL_WORDS

    # EA = A(1) = U0 ^ U1 ^ U2
    la t3, EA
    la t4, U0
    la t5, U1
    la t6, U2
    XOR3_WORDS t3, t4, t5, t6, EVAL_WORDS

    # EB = B(1) = V0 ^ V1 ^ V2
    la t3, EB
    la t4, V0
    la t5, V1
    la t6, V2
    XOR3_WORDS t3, t4, t5, t6, EVAL_WORDS

    # W1 = EA * EB
    la a0, W1
    la a1, EA
    la a2, EB
    li a3, EVAL_WORDS
    call scalar_mul

    # eval at x = X^w, w = 64
    # possible optimizations in changing w
    la t3, EA
    ZERO_WORDS t3, EVAL_WORDS

    la t3, EB
    ZERO_WORDS t3, EVAL_WORDS

    # EA = A(x) = U0 ^ (U1 << 64) ^ (U2 << 128)
    # EA[0..93] ^= U0[0..93]
    la t3, EA
    la t4, U0
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EA[1..94] ^= U1[0..93]
    la t3, EA
    addi t3, t3, 8
    la t4, U1
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EA[2..95] ^= U2[0..93]
    # can possibly reduce this
    la t3, EA
    addi t3, t3, 16
    la t4, U2
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EB = B(x) = V0 ^ (V1 << 64) ^ (V2 << 128)
    # EB[0..93] ^= V0[0..93]
    la t3, EB
    la t4, V0
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EB[1..94] ^= V1[0..93]
    la t3, EB
    addi t3, t3, 8
    la t4, V1
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EB[2..95] ^= V2[0..93]
    # can possibly reduce this
    la t3, EB
    addi t3, t3, 16
    la t4, V2
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # W2 = EA * EB
    la a0, W2
    la a1, EA
    la a2, EB
    li a3, EVAL_WORDS
    call scalar_mul

    # eval at x + 1 = X^64 + 1
    # w may change in optimizations
    la t3, EA
    ZERO_WORDS t3, EVAL_WORDS

    la t3, EB
    ZERO_WORDS t3, EVAL_WORDS

    # EA = A(x+1) = U0 ^ U1 ^ U2 ^ (U1 << 64) ^ (U2 << 128)
    # EA = U0 ^ U1 ^ U2
    la t3, EA
    la t4, U0
    la t5, U1
    la t6, U2
    XOR3_WORDS t3, t4, t5, t6, EVAL_WORDS

    # EA ^= U1 << 64
    # EA[1..94] ^= U1[0..93]
    la t3, EA
    addi t3, t3, 8
    la t4, U1
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EA ^= U2 << 128
    # EA[2..95] ^= U2[0..93]
    la t3, EA
    addi t3, t3, 16
    la t4, U2
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EB = B(x+1) = V0 ^ V1 ^ V2 ^ (V1 << 64) ^ (V2 << 128)
    # EB = V0 ^ V1 ^ V2
    la t3, EB
    la t4, V0
    la t5, V1
    la t6, V2
    XOR3_WORDS t3, t4, t5, t6, EVAL_WORDS

    # EB ^= V1 << 64
    # EB[1..94] ^= V1[0..93]
    la t3, EB
    addi t3, t3, 8
    la t4, V1
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # EB ^= V2 << 128
    # EB[2..95] ^= V2[0..93]
    la t3, EB
    addi t3, t3, 16
    la t4, V2
    XOR_INTO_WORDS t3, t4, TOOM_WORDS

    # W3 = EA * EB
    la a0, W3
    la a1, EA
    la a2, EB
    li a3, EVAL_WORDS
    call scalar_mul

    # already have U2, V2
    # W4 = U2 * V2
    la a0, W4
    la a1, U2
    la a2, V2
    li a3, EVAL_WORDS
    call scalar_mul

# TOOM3 INTERPOLATION


# write to output


# WIPE BUFFERS
# CLEANING SQUAD: RETURN OF THE KING
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

    la t3, EA
    ZERO_WORDS t3, EVAL_WORDS
    la t3, EB
    ZERO_WORDS t3, EVAL_WORDS

    la t3, W0
    ZERO_WORDS t3, PROD_WORDS
    la t3, W1
    ZERO_WORDS t3, PROD_WORDS
    la t3, W2
    ZERO_WORDS t3, PROD_WORDS
    la t3, W3
    ZERO_WORDS t3, PROD_WORDS
    la t3, W4
    ZERO_WORDS t3, PROD_WORDS
    

    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

    .size rvv_toom3_mul, .-rvv_toom3_mul