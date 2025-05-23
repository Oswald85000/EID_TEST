// ------------------------------------------------------------
// tests/make_vectors.c
// Génère vec.csv en Q16.16 saturé (10 000 aléatoires + 950 extrêmes)
// ------------------------------------------------------------
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* ---------- types fixe-point ---------- */
typedef int32_t q16_t;      /* Q16.16 */

/* ---------- saturations --------------- */
static inline int32_t sat32(int64_t v)
{
    return v >  0x7FFFFFFFLL ?  0x7FFFFFFF :
           v < -0x80000000LL ? -0x80000000 : (int32_t)v;
}
static inline int32_t sat32_pos(int64_t v)
{
    return v < 0              ? 0 :
           v > 0x7FFFFFFFLL   ? 0x7FFFFFFF : (int32_t)v;
}

/* ---------- arithmétique Q16.16 ------- */
static inline q16_t qmul_sat(q16_t a, q16_t b)
{ return (q16_t)sat32(((int64_t)a * b) >> 16); }

static inline int32_t qadd_sat(int32_t a, int32_t b)
{ return sat32((int64_t)a + b); }

/* ---------- constantes RTL ------------ */
#define A 0x00013333   /*  1.2 */
#define B 0x00010000   /*  1.0 */
#define G 0x00000CCD   /*  0.05 */
#define D 0x00000000   /*  0.0 */

/* ---------- pipeline logiciel --------- */
static int32_t p0 = 0, p1 = 0;
static int32_t step(q16_t H,q16_t F,q16_t O)
{
    int32_t n0 = qmul_sat(-A, H);
    int32_t n1 = qadd_sat(p0, qmul_sat(B, F));
    int32_t t1 = qadd_sat(p1, -qmul_sat(G, O));
    int32_t r  = sat32_pos((int64_t)t1 + D);
    p0 = n0;  p1 = n1;
    return r;
}

/* ---------- helper CSV ---------------- */
static void emit(q16_t H,q16_t F,q16_t O)
{
    printf("%d,%d,%d,%d\n", step(H,F,O), H, F, O);
}

/* générateur aléatoire Q16.16 ∈ [0,1[ */
static inline q16_t rand_q16(void)
{ return (q16_t)(rand() & 0xFFFF); }

/* ============================================================ */
int main(void)
{
    srand((unsigned)time(NULL));

    /* amorçage latence : 4 lignes nulles */
    for (int i = 0; i < 4; ++i) puts("0,0,0,0");

    /* 10 000 vecteurs pseudo-aléatoires ------------------------ */
    for (int i = 0; i < 10000; ++i)
        emit(rand_q16(), rand_q16(), rand_q16());

    /* ======== 750 vecteurs « extrêmes » historiques ========== */
    for (int i = 0; i < 125; ++i) emit(0x7FFF0000, 0x7FFF0000, 0); /* (1) ovflw + */
    for (int i = 0; i < 125; ++i) emit(0x80000000, 0x7FFF0000, 0); /* (2) underfl */
    for (int i = 0; i < 125; ++i) emit(0, 0, 0);                   /* (3) zéros   */
    for (int i = 0; i < 125; ++i) emit(0, 0x7FFF0000, 0);          /* (4) alarme F*/
    for (int i = 0; i < 125; ++i) emit(0, 0, 0x7FFF0000);          /* (5) t1 < 0  */
    for (int i = 0; i < 125; ++i) emit(0x7FFF0000, 0x7FFF0000, 0); /* (6) ovflw p1*/

    /* ======== 200 nouveaux vecteurs couvrant les 4 branches === */
    /* (10) qadd_sat : somme > +0x3FFF_FFFF  →  saturation +     */
    for (int i = 0; i < 40; ++i)
        emit(0x3FFF8000, 0x3FFF8000, 0);

    /* (11) qadd_sat : somme < -0x4000_0000 →  saturation −     */
    for (int i = 0; i < 40; ++i)
        emit(0x80008000, 0x80008000, 0);

    /* (12) qmul_sat : produit > +0x7FFF_FFFF → saturation +    */
    for (int i = 0; i < 40; ++i)
        emit(0x7FFF0000, 0x7FFF0000, 0);

    /* (13) qmul_sat : produit < -0x8000_0000 → saturation −    */
    for (int i = 0; i < 40; ++i)
        emit(0x80000000, 0x7FFF0000, 0);

    /* (14) 40 cycles consécutifs pour allumer alarm_r          */
    for (int i = 0; i < 40; ++i)
        emit(0x7FFF0000, 0x7FFF0000, 0);

    return 0;
}
