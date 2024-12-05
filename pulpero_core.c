#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <string.h>

typedef struct {
    lua_State *L;
    int runner_ref;  // Reference to the Runner instance
    int parser_ref;  // Reference to the Parser instance
} PulperoState;

PulperoState* pulpero_init() {
    PulperoState *state = malloc(sizeof(PulperoState));

    state->L = luaL_newstate();
    luaL_openlibs(state->L);

    luaL_dofile(state->L, "core/model_runner.lua");
    luaL_dofile(state->L, "core/setup.lua");
    luaL_dofile(state->L, "core/logger.lua");
    luaL_dofile(state->L, "core/parser.lua");


    lua_getglobal(state->L, "Logger");
    lua_getfield(state->L, -1, "new");
    lua_call(state->L, 0, 1);
    int logger_ref = luaL_ref(state->L, LUA_REGISTRYINDEX);

    lua_getglobal(state->L, "Setup");
    lua_getfield(state->L, -1, "new");
    lua_rawgeti(state->L, LUA_REGISTRYINDEX, logger_ref);
    lua_call(state->L, 1, 1);
    int setup_ref = luaL_ref(state->L, LUA_REGISTRYINDEX);

    lua_rawgeti(state->L, LUA_REGISTRYINDEX, setup_ref);
    lua_getfield(state->L, -1, "prepear_env");
    lua_call(state->L, 0, 0);

    lua_getglobal(state->L, "Runner");
    lua_getfield(state->L, -1, "new");
    lua_rawgeti(state->L, LUA_REGISTRYINDEX, setup_ref);
    lua_call(state->L, 1, 1);
    state->runner_ref = luaL_ref(state->L, LUA_REGISTRYINDEX);

    return state;
}

const char* pulpero_explain_code(PulperoState *state, const char* code, const char* language) {

    lua_rawgeti(state->L, LUA_REGISTRYINDEX, state->runner_ref);
    lua_getfield(state->L, -1, "explain_function");


    lua_pushstring(state->L, code);
    lua_pushstring(state->L, language);


    if (lua_pcall(state->L, 2, 3, 0) != 0) {
        return lua_pushstring(state->L, "Error executing function");
    }


    const char* result = lua_tostring(state->L, -2);
    char* output = strdup(result);  // Create persistent copy
    lua_pop(state->L, 3);

    return output;
}

void pulpero_cleanup(PulperoState *state) {
    luaL_unref(state->L, LUA_REGISTRYINDEX, state->runner_ref);
    lua_close(state->L);
    free(state);
}
