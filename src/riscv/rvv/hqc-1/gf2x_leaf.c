#include <stdint.h>
#include <stddef.h>
#include <string.h>

static inline void shl_b_0(uint64_t out[4], const uint64_t b[3]) {
    out[0] = b[0];
    out[1] = b[1];
    out[2] = b[2];
    out[3] = 0;
}

static inline void shl_b_1(uint64_t out[4], const uint64_t b[3]) {
    out[0] = b[0] << 1;
    out[1] = (b[1] << 1) ^ (b[0] >> 63);
    out[2] = (b[2] << 1) ^ (b[1] >> 63);
    out[3] = b[2] >> 63;
}

static inline void shl_b_2(uint64_t out[4], const uint64_t b[3]) {
    out[0] = b[0] << 2;
    out[1] = (b[1] << 2) ^ (b[0] >> 62);
    out[2] = (b[2] << 2) ^ (b[1] >> 62);
    out[3] = b[2] >> 62;
}

static inline void shl_b_3(uint64_t out[4], const uint64_t b[3]) {
    out[0] = b[0] << 3;
    out[1] = (b[1] << 3) ^ (b[0] >> 61);
    out[2] = (b[2] << 3) ^ (b[1] >> 61);
    out[3] = b[2] >> 61;
}

#define APPLY_NIBBLE_0(r, off, row) do {        \
    (r)[(off) + 0] ^= (row)[0];                 \
    (r)[(off) + 1] ^= (row)[1];                 \
    (r)[(off) + 2] ^= (row)[2];                 \
    (r)[(off) + 3] ^= (row)[3];                 \
} while (0)

#define APPLY_NIBBLE_SHIFT(r, off, row, sh) do {        \
    enum { INV = 64 - (sh) };                           \
    uint64_t x0 = (row)[0];                             \
    uint64_t x1 = (row)[1];                             \
    uint64_t x2 = (row)[2];                             \
    uint64_t x3 = (row)[3];                             \
    (r)[(off) + 0] ^= x0 << (sh);                       \
    (r)[(off) + 1] ^= (x1 << (sh)) ^ (x0 >> INV);       \
    (r)[(off) + 2] ^= (x2 << (sh)) ^ (x1 >> INV);       \
    (r)[(off) + 3] ^= (x3 << (sh)) ^ (x2 >> INV);       \
    (r)[(off) + 4] ^= x3 >> INV;                       \
} while (0)

#define APPLY_WORD(r, off, ai, table) do {                              \
    const uint64_t *row0  = (table)[((ai) >>  0) & 0xFULL];             \
    const uint64_t *row4  = (table)[((ai) >>  4) & 0xFULL];             \
    const uint64_t *row8  = (table)[((ai) >>  8) & 0xFULL];             \
    const uint64_t *row12 = (table)[((ai) >> 12) & 0xFULL];             \
    const uint64_t *row16 = (table)[((ai) >> 16) & 0xFULL];             \
    const uint64_t *row20 = (table)[((ai) >> 20) & 0xFULL];             \
    const uint64_t *row24 = (table)[((ai) >> 24) & 0xFULL];             \
    const uint64_t *row28 = (table)[((ai) >> 28) & 0xFULL];             \
    const uint64_t *row32 = (table)[((ai) >> 32) & 0xFULL];             \
    const uint64_t *row36 = (table)[((ai) >> 36) & 0xFULL];             \
    const uint64_t *row40 = (table)[((ai) >> 40) & 0xFULL];             \
    const uint64_t *row44 = (table)[((ai) >> 44) & 0xFULL];             \
    const uint64_t *row48 = (table)[((ai) >> 48) & 0xFULL];             \
    const uint64_t *row52 = (table)[((ai) >> 52) & 0xFULL];             \
    const uint64_t *row56 = (table)[((ai) >> 56) & 0xFULL];             \
    const uint64_t *row60 = (table)[((ai) >> 60) & 0xFULL];             \
                                                                        \
    APPLY_NIBBLE_0((r), (off), row0);                                   \
    APPLY_NIBBLE_SHIFT((r), (off), row4,  4);                           \
    APPLY_NIBBLE_SHIFT((r), (off), row8,  8);                           \
    APPLY_NIBBLE_SHIFT((r), (off), row12, 12);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row16, 16);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row20, 20);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row24, 24);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row28, 28);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row32, 32);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row36, 36);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row40, 40);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row44, 44);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row48, 48);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row52, 52);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row56, 56);                          \
    APPLY_NIBBLE_SHIFT((r), (off), row60, 60);                          \
} while (0)

static inline void gf2x_mul3_fast(uint64_t *restrict r,
                                  const uint64_t *restrict a,
                                  const uint64_t *restrict b)
{
    uint64_t table[16][4];
    uint64_t p1[4], p2[4], p4[4], p8[4];

    r[0] = 0;
    r[1] = 0;
    r[2] = 0;
    r[3] = 0;
    r[4] = 0;
    r[5] = 0;
    r[6] = 0;

    shl_b_0(p1, b);
    shl_b_1(p2, b);
    shl_b_2(p4, b);
    shl_b_3(p8, b);

    for (unsigned v = 0; v < 16; v++) {
        uint64_t t0 = 0;
        uint64_t t1 = 0;
        uint64_t t2 = 0;
        uint64_t t3 = 0;

        if (v & 1U) {
            t0 ^= p1[0];
            t1 ^= p1[1];
            t2 ^= p1[2];
            t3 ^= p1[3];
        }

        if (v & 2U) {
            t0 ^= p2[0];
            t1 ^= p2[1];
            t2 ^= p2[2];
            t3 ^= p2[3];
        }

        if (v & 4U) {
            t0 ^= p4[0];
            t1 ^= p4[1];
            t2 ^= p4[2];
            t3 ^= p4[3];
        }

        if (v & 8U) {
            t0 ^= p8[0];
            t1 ^= p8[1];
            t2 ^= p8[2];
            t3 ^= p8[3];
        }

        table[v][0] = t0;
        table[v][1] = t1;
        table[v][2] = t2;
        table[v][3] = t3;
    }

    uint64_t a0 = a[0];
    uint64_t a1 = a[1];
    uint64_t a2 = a[2];

    APPLY_WORD(r, 0, a0, table);
    APPLY_WORD(r, 1, a1, table);
    APPLY_WORD(r, 2, a2, table);
}


void scalar_mul(uint64_t *restrict r,
                const uint64_t *restrict a,
                const uint64_t *restrict b,
                size_t nwords)
{
    if (__builtin_expect(nwords == 3, 1)) {
        gf2x_mul3_fast(r, a, b);
        return;
    }


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