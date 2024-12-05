#ifndef PULPERO_H
#define PULPERO_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PulperoState PulperoState;

// Library functions
PulperoState* pulpero_init();
const char* pulpero_explain_code(PulperoState *state, const char* code, const char* language);
void pulpero_cleanup(PulperoState *state);

#ifdef __cplusplus
}
#endif

#endif // PULPERO_H
