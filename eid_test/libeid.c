#include <stdio.h>
#include "libeid.h"

float eid_update(eid_ctx_t *c,float H,float F,float O,bool *alarm){
    float dHdt = -c->alpha*H + c->beta*F - c->gamma*O + c->delta;
    *alarm = ((c->alpha/c->beta) < 1.0f);
    return dHdt;
}

#ifdef EID_DEMO
int main(void){
    eid_ctx_t ctx; eid_init(&ctx,1.2f,1.0f,0.05f,0.01f);
    float H=1.0f,F=0.1f,O=0.0f; for(int t=0;t<10;++t){
        bool alarm; float d=eid_update(&ctx,H,F,O,&alarm); H+=d*0.001f;
        printf("t=%d  H=%.4f  dH/dt=%+.4f  ALARM=%d\n",t,H,d,alarm);
    }
}
#endif
