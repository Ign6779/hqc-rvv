#include "gf2x_macros.inc"

    .text
    .extern scalar_mul

    .globl rvv_kara96_mul
    .type rvv_kara96_mul, @function

# void rvv_kara96_mul(uint64_t *out, const uint64_t *a, const uint64_t *b)
# a0 = out
# a1 = a
# a2 = b
rvv_kara96_mul:
    addi sp, sp, -16
    sd ra, 8(sp)
    sd s0, 0(sp)

    # fallback:
    # call scalar_mul(out, a, b, 96)
    li a3, EVAL_WORDS
    call scalar_mul

    ld s0, 0(sp)
    ld ra, 8(sp)
    addi sp, sp, 16
    ret

    .size rvv_kara96_mul, .-rvv_kara96_mul