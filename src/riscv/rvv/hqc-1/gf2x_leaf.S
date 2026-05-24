#include "gf2x_macros.inc"

    .text
    .globl rvv_leaf_mul
    .type rvv_leaf_mul, @function

rvv_leaf_mul:
    addi sp, sp, -64
    sd ra, 56(sp)
    sd s0, 48(sp)
    sd s1, 40(sp)
    sd s2, 32(sp)
    sd s3, 24(sp)
    sd s4, 16(sp)
    sd s5, 8(sp)
    sd s6, 0(sp)

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3

    slli t0, s3, 1
    addi t0, t0, 1
    mv t3, s0

.L_leaf_zero_loop:
    beqz t0, .L_leaf_zero_done

    VSETVLI_E64_M1(t1, t0)
    vmv.v.i v0, 0
    vse64.v v0, (t3)

    slli t2, t1, 3
    add t3, t3, t2
    sub t0, t0, t1
    j .L_leaf_zero_loop

.L_leaf_zero_done:


# for i = 0; i < nwords; i++
    li s4, 0           # s4 = i

.L_leaf_i_loop:
    beq s4, s3, .L_leaf_done

    # Load ai = a[i]
    slli t0, s4, 3
    add t1, s1, t0
    ld s5, 0(t1)       # s5 = ai

    li s6, 0           # s6 = bit

.L_leaf_bit_loop:
    li t0, 64
    beq s6, t0, .L_leaf_next_i

    # mask = 0 - ((ai >> bit) & 1)
    srl t1, s5, s6
    andi t1, t1, 1
    neg t1, t1         # t1 = mask: 0 or all-ones

    beqz s6, .L_leaf_bit_zero

# bit != 0 case:
# for j:
#   bj = b[j] & mask
#   out[i+j]   ^= bj << bit
#   out[i+j+1] ^= bj >> (64 - bit)
    li t2, 64
    sub t2, t2, s6

    mv t3, s3
    mv t4, s2

    # out pointer starts at out + i words
    slli t5, s4, 3
    add t6, s0, t5

.L_leaf_j_shift_loop:
    beqz t3, .L_leaf_bit_done

    VSETVLI_E64_M1(t0, t3)

    # vb = b[j..] & mask
    vle64.v v0, (t4)
    vand.vx v0, v0, t1

    # lo = vb << bit
    vsll.vx v1, v0, s6

    # out[i+j..] ^= lo
    vle64.v v2, (t6)
    vxor.vv v2, v2, v1
    vse64.v v2, (t6)

    # hi = vb >> (64 - bit)
    vsrl.vx v3, v0, t2

    # out[i+j+1..] ^= hi
    addi t5, t6, 8
    vle64.v v4, (t5)
    vxor.vv v4, v4, v3
    vse64.v v4, (t5)

    # advance pointers
    slli t5, t0, 3
    add t4, t4, t5     # b += vl
    add t6, t6, t5     # out += vl
    sub t3, t3, t0
    j .L_leaf_j_shift_loop


# bit == 0 case:
# for j:
#   out[i+j] ^= b[j] & mask
.L_leaf_bit_zero:
    mv t3, s3
    mv t4, s2

    slli t5, s4, 3
    add t6, s0, t5

.L_leaf_j_zero_loop:
    beqz t3, .L_leaf_bit_done

    VSETVLI_E64_M1(t0, t3)

    vle64.v v0, (t4)
    vand.vx v0, v0, t1

    vle64.v v1, (t6)
    vxor.vv v1, v1, v0
    vse64.v v1, (t6)

    slli t5, t0, 3
    add t4, t4, t5
    add t6, t6, t5
    sub t3, t3, t0
    j .L_leaf_j_zero_loop


.L_leaf_bit_done:
    addi s6, s6, 1
    j .L_leaf_bit_loop


.L_leaf_next_i:
    addi s4, s4, 1
    j .L_leaf_i_loop


.L_leaf_done:
    ld s6, 0(sp)
    ld s5, 8(sp)
    ld s4, 16(sp)
    ld s3, 24(sp)
    ld s2, 32(sp)
    ld s1, 40(sp)
    ld s0, 48(sp)
    ld ra, 56(sp)
    addi sp, sp, 64
    ret

    .size rvv_leaf_mul, .-rvv_leaf_mul