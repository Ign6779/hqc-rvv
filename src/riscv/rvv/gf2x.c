/**
 * \file gf2x.c
 * \brief RVV implementation wrapper for Toom-Karatsuba multiplication of two polynomials.
 */

#include "gf2x.h"
#include "parameters.h"

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define GF2X_PAD_WORDS        (PARAM_N_MULT / 64)
#define GF2X_UNREDUCED_WORDS  (2 * GF2X_PAD_WORDS + 1)

/**
 * Implemented in the specific assembly file:
 *
 *   hqc-1/gf2x_toom.S
 *   hqc-3/gf2x_toom.S
 *   hqc-5/gf2x_toom.S
 *
 * @brief Computes tmp = a1 * a2 over GF(2)[X].
 *
 * tmp must have GF2X_UNREDUCED_WORDS words available.
 */
extern void rvv_toom3_mul(uint64_t *tmp, const uint64_t *a1, const uint64_t *a2);

/**
 * Implemented in gf2x_reduce.S.
 *
 * @brief Modular reduction of a degree < 2n polynomial modulo X^n - 1.
 */
extern void rvv_reduce(uint64_t *o, const uint64_t *tmp);

void scalar_mult(uint64_t *r, const uint64_t *a, const uint64_t *b, size_t nwords);

/**
 * @brief Scalar bottom multiplication over GF(2)[X].
 *
 * Computes:
 *   r = a * b
 *
 * where a and b each contain nwords 64-bit words.
 * r must have room for 2 * nwords + 1 words.
 *
 * temporary
 */
void scalar_mult(uint64_t *r, const uint64_t *a, const uint64_t *b, size_t nwords) {
    memset(r, 0, (2 * nwords + 1) * sizeof(uint64_t));

    for (size_t i = 0; i < nwords; i++) {
        uint64_t ai = a[i];

        for (unsigned bit = 0; bit < 64; bit++) {
            uint64_t mask = (uint64_t)0 - ((ai >> bit) & 1ULL);

            if (bit == 0) {
                for (size_t j = 0; j < nwords; j++) {
                    r[i + j] ^= b[j] & mask;
                }
            } else {
                unsigned inv = 64U - bit;

                for (size_t j = 0; j < nwords; j++) {
                    uint64_t bj = b[j] & mask;

                    r[i + j]     ^= bj << bit;
                    r[i + j + 1] ^= bj >> inv;
                }
            }
        }
    }
}

/**
 * @brief Multiply two polynomials modulo X^n - 1.
 *
 * This function multiplies two dense binary polynomials without using sparsity.
 *
 * @param[out] o  Result polynomial, VEC_N_SIZE_64 words.
 * @param[in] a1  First input polynomial, VEC_N_SIZE_64 words.
 * @param[in] a2  Second input polynomial, VEC_N_SIZE_64 words.
 */
void vect_mul(uint64_t *o, const uint64_t *a1, const uint64_t *a2)
{
    uint64_t tmp[GF2X_UNREDUCED_WORDS];

    memset(tmp, 0, sizeof(tmp));

    rvv_toom3_mul(tmp, a1, a2);
    rvv_reduce(o, tmp);

    memset(tmp, 0, sizeof(tmp));
}