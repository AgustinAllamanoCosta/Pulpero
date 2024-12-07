cmake_minimum_required(VERSION 3.10)
project(pulpero VERSION 1.0)

find_package(Lua REQUIRED)

set(PULPERO_LUA_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lua/pulpero/core)
set(PULPERO_SOURCES
    ${PULPERO_LUA_DIR}/logger.lua
    ${PULPERO_LUA_DIR}/model_runner.lua
    ${PULPERO_LUA_DIR}/parser.lua
    ${PULPERO_LUA_DIR}/setup.lua
)

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/pulpero_wrapper.c
[=[
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <string.h>
#include <stdlib.h>
#include "pulpero.h"

struct PulperoContext {
    lua_State *L;
    char* last_error;
    int runner_ref;
};

PulperoContext* pulpero_init(void) {
    PulperoContext* ctx = malloc(sizeof(PulperoContext));
    ctx->L = luaL_newstate();
    luaL_openlibs(ctx->L);

    luaL_dostring(ctx->L, "package.path = package.path .. ';${PULPERO_LUA_DIR}/?.lua'");

    if (luaL_dofile(ctx->L, "${PULPERO_LUA_DIR}/logger.lua") != 0 ||
        luaL_dofile(ctx->L, "${PULPERO_LUA_DIR}/setup.lua") != 0 ||
        luaL_dofile(ctx->L, "${PULPERO_LUA_DIR}/parser.lua") != 0 ||
        luaL_dofile(ctx->L, "${PULPERO_LUA_DIR}/model_runner.lua") != 0) {
        const char* error = lua_tostring(ctx->L, -1);
        ctx->last_error = strdup(error);
        return ctx;
    }

    lua_getglobal(ctx->L, "Logger");
    lua_getfield(ctx->L, -1, "new");
    lua_call(ctx->L, 0, 1);
    int logger_ref = luaL_ref(ctx->L, LUA_REGISTRYINDEX);

    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, logger_ref);
    lua_getfield(ctx->L, -1, "clear_logs");
    lua_pushvalue(ctx->L, -2);
    lua_call(ctx->L, 1, 0);

    lua_getglobal(ctx->L, "Setup");
    lua_getfield(ctx->L, -1, "new");
    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, logger_ref);
    lua_call(ctx->L, 1, 1);
    int setup_ref = luaL_ref(ctx->L, LUA_REGISTRYINDEX);

    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, setup_ref);
    lua_getfield(ctx->L, -1, "configure_plugin");
    lua_pushvalue(ctx->L, -2);
    lua_call(ctx->L, 1, 1);

    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, logger_ref);
    lua_getfield(ctx->L, -1, "debug");
    lua_pushvalue(ctx->L, -2);
    lua_pushstring(ctx->L, "Configuration");
    lua_pushvalue(ctx->L, -5);
    lua_call(ctx->L, 3, 0);

    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, setup_ref);
    lua_getfield(ctx->L, -1, "prepear_env");
    lua_pushvalue(ctx->L, -2);
    lua_call(ctx->L, 1, 0);

    lua_getglobal(ctx->L, "Parser");
    lua_getfield(ctx->L, -1, "new");
    lua_pushvalue(ctx->L, -4);
    lua_call(ctx->L, 1, 1);
    int parser_ref = luaL_ref(ctx->L, LUA_REGISTRYINDEX);

    lua_getglobal(ctx->L, "Runner");
    lua_getfield(ctx->L, -1, "new");
    lua_pushvalue(ctx->L, -4);
    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, logger_ref);
    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, parser_ref);
    lua_call(ctx->L, 3, 1);
    ctx->runner_ref = luaL_ref(ctx->L, LUA_REGISTRYINDEX);

    luaL_unref(ctx->L, LUA_REGISTRYINDEX, logger_ref);
    luaL_unref(ctx->L, LUA_REGISTRYINDEX, setup_ref);
    luaL_unref(ctx->L, LUA_REGISTRYINDEX, parser_ref);

    return ctx;
}

const char* pulpero_explain_code(PulperoContext* ctx, const char* code, const char* language) {
    lua_rawgeti(ctx->L, LUA_REGISTRYINDEX, ctx->runner_ref);
    lua_getfield(ctx->L, -1, "explain_function");
    lua_pushvalue(ctx->L, -2);
    lua_pushstring(ctx->L, language);
    lua_pushstring(ctx->L, code);
    if (lua_pcall(ctx->L, 3, 2, 0) != 0) {
        const char* error = lua_tostring(ctx->L, -1);
        return strdup(error);
    }
    const char* result;
    if (lua_toboolean(ctx->L, -2)) {
        result = lua_tostring(ctx->L, -2);
    } else {
        result = lua_tostring(ctx->L, -1);
    }
    return strdup(result);
}

void pulpero_cleanup(PulperoContext* ctx) {
    if (ctx) {
        if (ctx->L) {
            luaL_unref(ctx->L, LUA_REGISTRYINDEX, ctx->runner_ref);
            lua_close(ctx->L);
        }
        if (ctx->last_error) {
            free(ctx->last_error);
        }
        free(ctx);
    }
}
]=])

file(WRITE ${CMAKE_CURRENT_BINARY_DIR}/pulpero.h
[=[
#ifndef PULPERO_H
#define PULPERO_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PulperoContext PulperoContext;

PulperoContext* pulpero_init(void);

void pulpero_cleanup(PulperoContext* ctx);

const char* pulpero_explain_code(PulperoContext* ctx, const char* code, const char* language);

#ifdef __cplusplus
}
#endif

#endif
]=])

add_library(pulpero SHARED
    ${CMAKE_CURRENT_BINARY_DIR}/pulpero_wrapper.c
)

target_include_directories(pulpero
    PUBLIC
        ${CMAKE_CURRENT_BINARY_DIR}
    PRIVATE
        ${LUA_INCLUDE_DIR}
)

target_link_libraries(pulpero PRIVATE ${LUA_LIBRARIES})

install(TARGETS pulpero
    LIBRARY DESTINATION lib
    RUNTIME DESTINATION bin
)

install(FILES ${CMAKE_CURRENT_BINARY_DIR}/pulpero.h
    DESTINATION include
)

install(DIRECTORY ${PULPERO_LUA_DIR}/
    DESTINATION share/pulpero/lua/core
    FILES_MATCHING PATTERN "*.lua"
)
