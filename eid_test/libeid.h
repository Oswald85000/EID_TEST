#ifndef LIBEID_H
#define LIBEID_H
#include <stdbool.h>

typedef struct { float alpha, beta, gamma, delta; } eid_ctx_t;

static inline void eid_init(eid_ctx_t *c,float a,float b,float g,float d){
    c->alpha=a; c->beta=b; c->gamma=g; c->delta=d;
}

float eid_update(eid_ctx_t *c,float H,float F,float O,bool *alarm);
#endif
