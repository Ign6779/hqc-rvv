#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include "gf2x.h"
#include "parameters.h"

/**
 * @brief Modular reduction of a degree < 2*n polynomial mod (X^n - 1).
 *
 * Folds the high half of the full product back into the low half
 * and masks any excess bits in the last word.
 *
 * @param[out] o  Result buffer, size VEC_N_SIZE_64 words.
 * @param[in]  a  Input buffer, size 2*VEC_N_SIZE_64 words.
 */
static void reduce(uint64_t *o, const uint64_t *a) {
    for (size_t i = 0; i < VEC_N_SIZE_64; i++) {
        uint64_t r = a[i + VEC_N_SIZE_64 - 1] >> (PARAM_N & 0x3F);
        uint64_t carry = a[i + VEC_N_SIZE_64] << (64 - (PARAM_N & 0x3F));
        o[i] = a[i] ^ r ^ carry;
    }

    o[VEC_N_SIZE_64 - 1] &= BITMASK(PARAM_N, 64);
}

/**
 * @brief convert a dense polynomial into a support array.
 *
 * support receives the bit positions where dense has coefficient 1.
 *
 * @param[out] support  Array of size at least PARAM_N.
 * @param[in]  dense    Dense polynomial, size VEC_N_SIZE_64 words.
 *
 * @return Hamming weight of dense.
 */
static size_t dense_to_support(uint32_t *support, const uint64_t *dense) {
    size_t weight = 0;

    for (uint32_t bit_pos = 0; bit_pos < PARAM_N; bit_pos++) {
        size_t word_index = bit_pos / 64;
        unsigned int bit_index = bit_pos % 64;

        if ((dense[word_index] >> bit_index) & 1ULL) {
            support[weight] = bit_pos;
            weight++;
        }
    }

    return weight;
}

/*
 * unreduced sparse x dense multiplication over GF(2).
 * WARNING: NOT secure, NOT constant-time
 *
 * support: positions of 1 bits in the sparse polynomial
 * weight: number of entries in support
 * dense: dense polynomial as uint64_t words
 * result: unreduced output buffer
 */
static void sparse_dense_mult(
    uint64_t *result,
    const uint32_t *support,
    size_t weight,
    const uint64_t *dense
) {
    memset(result, 0, 2 * VEC_N_SIZE_64 * sizeof(uint64_t));

    for (size_t i = 0; i < weight; i++) {
        uint32_t shift = support[i];

        size_t word_shift = shift / 64;
        unsigned int bit_shift = shift % 64;

        for (size_t j = 0; j < VEC_N_SIZE_64; j++) {
            uint64_t x = dense[j];

            if (j == VEC_N_SIZE_64 - 1) {
                x &= BITMASK(PARAM_N, 64);
            }

            result[j + word_shift] ^= x << bit_shift;

            if (bit_shift != 0) {
                result[j + word_shift + 1] ^= x >> (64 - bit_shift);
            }
        }
    }
}

/**
 * @brief carry-less multiplication mod X^PARAM_N - 1.
 *
 * replacement for the reference vect_mul.
 *
 * this version detects which input is sparser, converts that input into
 * support form, then performs sparse x dense multiplication.
 *
 * WARNING: this is for testing only. It is not constant-time.
 *
 * @param[out] o   Result buffer, size VEC_N_SIZE_64 words.
 * @param[in]  v1  First input polynomial, dense representation.
 * @param[in]  v2  Second input polynomial, dense representation.
 */
void vect_mul(uint64_t *o, const uint64_t *v1, const uint64_t *v2) {
    uint64_t unreduced[2 * VEC_N_SIZE_64];

    uint32_t support1[PARAM_N];
    uint32_t support2[PARAM_N];

    size_t weight1 = dense_to_support(support1, v1);
    size_t weight2 = dense_to_support(support2, v2);

    if (weight1 <= weight2) {
        sparse_dense_mult(unreduced, support1, weight1, v2);
    } else {
        sparse_dense_mult(unreduced, support2, weight2, v1);
    }

    reduce(o, unreduced);
}