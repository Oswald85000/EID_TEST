#pragma once
#include <stdint.h>

/* ---------------------------------------------------------------------------
   Opérations Q16.16 signées 32 b avec saturation
   ------------------------------------------------------------------------- */
static inline int32_t q32_mul(int32_t a, int32_t b)          /* Q16.16 × Q16.16 */
{
    int64_t p = (int64_t)a * b;   /* Q32.32 */
    p >>= 16;                     /* -> Q16.16 */
    if (p >  0x7FFFFFFF) p =  0x7FFFFFFF;
    if (p < -0x80000000LL) p = -0x80000000LL;
    return (int32_t)p;
}

static inline int32_t q32_add(int32_t a, int32_t b)
{
    int64_t s = (int64_t)a + b;
    if (s >  0x7FFFFFFF) s =  0x7FFFFFFF;
    if (s < -0x80000000LL) s = -0x80000000LL;
    return (int32_t)s;
}
