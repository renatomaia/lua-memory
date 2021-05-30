#define lmemlib_c

#define LUAMEMLIB_API

#include "lmemlib.h"

#include <string.h>


static int typeerror (lua_State *L, int arg, const char *tname);


LUAMEMLIB_API char *luamem_newalloc (lua_State *L, size_t l) {
	char *mem = (char *)lua_newuserdatauv(L, l * sizeof(char), 0);
	luaL_newmetatable(L, LUAMEM_ALLOC);
	lua_setmetatable(L, -2);
	return mem;
}

typedef struct luamem_Ref {
	char *mem;
	size_t len;
	luamem_Unref unref;
} luamem_Ref;

#define unrefmem(L,r)	if (r->unref) ref->unref(L, r->mem, r->len)

static int luaunref (lua_State *L) {
	luamem_Ref *ref = (luamem_Ref *)luaL_testudata(L, 1, LUAMEM_REF);
	if (ref) unrefmem(L, ref);
	return 0;
}

LUAMEMLIB_API void luamem_newref (lua_State *L) {
	luamem_Ref *ref = (luamem_Ref *)lua_newuserdatauv(L, sizeof(luamem_Ref), 0);
	ref->mem = NULL;
	ref->len = 0;
	ref->unref = NULL;
	if (luaL_newmetatable(L, LUAMEM_REF)) {
		lua_pushcfunction(L, luaunref);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
}

LUAMEMLIB_API int luamem_setref (lua_State *L, int idx, 
                                 char *mem, size_t len, luamem_Unref unref) {
	luamem_Ref *ref = (luamem_Ref *)luaL_testudata(L, idx, LUAMEM_REF);
	if (ref) {
		if (mem != ref->mem) {
			unrefmem(L, ref);
			ref->mem = mem;
		}
		ref->len = len;
		ref->unref = unref;
		return 1;
	}
	return 0;
}

LUAMEMLIB_API int luamem_type (lua_State *L, int idx) {
	int type = LUAMEM_TNONE;
	if (lua_type(L, idx) == LUA_TUSERDATA) {
		if (lua_getmetatable(L, idx)) {  /* does it have a metatable? */
			luaL_getmetatable(L, LUAMEM_ALLOC);  /* get allocated memory metatable */
			if (lua_rawequal(L, -1, -2)) type = LUAMEM_TALLOC;
			else {
				lua_pop(L, 1);  /* remove allocated memory metatable */
				luaL_getmetatable(L, LUAMEM_REF);  /* get referenced memory metatable */
				if (lua_rawequal(L, -1, -2)) type = LUAMEM_TREF;
			}
			lua_pop(L, 2);  /* remove both metatables */
		}
	}
	return type;
}

LUAMEMLIB_API char *luamem_tomemoryx (lua_State *L, int idx,
                                      size_t *len, luamem_Unref *unref,
                                      int *type) {
	int typemem;
	if (!type) type = &typemem;
	*type = luamem_type(L, idx);
	switch (*type) {
		case LUAMEM_TALLOC:
			if (len) *len = lua_rawlen(L, idx);
			if (unref) *unref = NULL;
			return (char *)lua_touserdata(L, idx);
		case LUAMEM_TREF: {
			luamem_Ref *ref = (luamem_Ref *)lua_touserdata(L, idx);
			if (len) *len = ref->len;
			if (unref) *unref = ref->unref;
			return ref->mem;
		}
	}
	if (len) *len = 0;
	if (unref) *unref = NULL;
	return NULL;
}

LUAMEMLIB_API char *luamem_checkmemory (lua_State *L, int arg, size_t *len) {
	int type;
	char *mem = luamem_tomemoryx(L, arg, len, NULL, &type);
	if (type == LUAMEM_TNONE) typeerror(L, arg, "memory");
	return mem;
}


LUAMEMLIB_API int luamem_isstring (lua_State *L, int idx) {
	return (lua_isstring(L, idx) || luamem_ismemory(L, idx));
}

LUAMEMLIB_API const char *luamem_tostring (lua_State *L, int idx, size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, idx, len, NULL, &type);
	if (type == LUAMEM_TNONE) return lua_tolstring(L, idx, len);
	return s;
}

LUAMEMLIB_API const char *luamem_asstring (lua_State *L, int idx, size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, idx, len, NULL, &type);
	if (type == LUAMEM_TNONE) return luaL_tolstring(L, idx, len);
	return s;
}

LUAMEMLIB_API const char *luamem_checkstring (lua_State *L,
                                              int arg,
                                              size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, arg, len, NULL, &type);
	if (type == LUAMEM_TNONE) {
		s = lua_tolstring(L, arg, len);
		if (!s) typeerror(L, arg, "string or memory");
	}
	return s;
}

LUAMEMLIB_API const char *luamem_optstring (lua_State *L,
                                            int arg,
                                            const char *def,
                                            size_t *len) {
	if (lua_isnoneornil(L, arg)) {
		if (len)
			*len = (def ? strlen(def) : 0);
		return def;
	}
	else return luamem_checkstring(L, arg, len);
}


LUAMEMLIB_API void *luamem_realloc(lua_State *L, void *mem, size_t osize,
                                                            size_t nsize) {
	void *userdata;
	lua_Alloc alloc = lua_getallocf(L, &userdata);
	return alloc(userdata, mem, osize, nsize);
}

LUAMEMLIB_API void luamem_free(lua_State *L, void *mem, size_t size) {
	luamem_realloc(L, mem, size, 0);
}

LUAMEMLIB_API size_t luamem_checklenarg (lua_State *L, int idx) {
	lua_Integer sz = luaL_checkinteger(L, idx);
	luaL_argcheck(L, 0 <= sz && sz < (lua_Integer)LUAMEM_MAXSIZE,
	                 idx, "invalid size");
	return (size_t)sz;
}

/*
* NOTE: most of the code below is copied from the source of Lua 5.4.0 by
*       R. Ierusalimschy, L. H. de Figueiredo, W. Celes - Lua.org, PUC-Rio.
*
* Copyright (C) 1994-2020 Lua.org, PUC-Rio.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

static int typeerror (lua_State *L, int arg, const char *tname) {
	const char *msg;
	const char *typearg;  /* name for the type of the actual argument */
	if (luaL_getmetafield(L, arg, "__name") == LUA_TSTRING)
		typearg = lua_tostring(L, -1);  /* use the given type name */
	else if (lua_type(L, arg) == LUA_TLIGHTUSERDATA)
		typearg = "light userdata";  /* special name for messages */
	else
		typearg = luaL_typename(L, arg);  /* standard name */
	msg = lua_pushfstring(L, "%s expected, got %s", tname, typearg);
	return luaL_argerror(L, arg, msg);
}

/*
** {======================================================
** Generic Buffer manipulation
** =======================================================
*/

/*
** check whether buffer is using a userdata on the stack as a temporary
** buffer
*/
#define buffonstack(B)	((B)->b != (B)->init.b)


LUAMEMLIB_API void luamem_pushresult (luaL_Buffer *B) {
	lua_State *L = B->L;
	if (!buffonstack(B) || B->n < B->size) {
		char *p = (char *)luamem_newalloc(L, B->n * sizeof(char));
		/* move content to new buffer */
		memcpy(p, B->b, B->n * sizeof(char));
		if (buffonstack(B))
			lua_remove(L, -2);  /* remove old buffer */
	}
}


LUAMEMLIB_API void luamem_pushresultsize (luaL_Buffer *B, size_t sz) {
	luaL_addsize(B, sz);
	luamem_pushresult(B);
}


LUAMEMLIB_API void luamem_addvalue (luaL_Buffer *B) {
	lua_State *L = B->L;
	size_t l;
	const char *s = luamem_tostring(L, -1, &l);
	if (buffonstack(B))
		lua_insert(L, -2);  /* put value below buffer */
	luaL_addlstring(B, s, l);
	lua_remove(L, (buffonstack(B)) ? -2 : -1);  /* remove value */
}

/* }====================================================== */
