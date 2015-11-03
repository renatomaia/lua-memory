/*
** $Id$
** Stream support for the Lua language
** See Copyright Notice in lstraux.h
*/

#define lbuflib_c

#include "lstraux.h"
#include "lstrops.h"

#include <string.h>



static int buf_create (lua_State *L) {
	char *p;
	size_t l;
	const char *s = NULL;
	if (lua_type(L, 1) == LUA_TNUMBER) {
		lua_Integer sz = luaL_checkinteger(L, 1);
		luaL_argcheck(L, 0 <= sz && sz < (lua_Integer)LUABUF_MAXSIZE, 1,
		                                                    "invalid size");
		l = (size_t)sz;
	} else {
		lua_Integer posi, pose;
		s = luabuf_checkstream(L, 1, &l);
		posi = luastreamI_posrelat(luaL_optinteger(L, 2, 1), l);
		pose = luastreamI_posrelat(luaL_optinteger(L, 3, -1), l);
		if (posi < 1) posi = 1;
		if (pose > (lua_Integer)l) pose = l;
		if (posi > pose) {
			l = 0;
			s = NULL;
		} else {
			l = (int)(pose - posi + 1);
			if (posi + l <= pose)  /* arithmetic overflow? */
				return luaL_error(L, "string slice too long");
			s += posi-1;
		}
	}
	p = luabuf_newbuffer(L, l);
	if (s) memcpy(p, s, l * sizeof(char));
	return 1;
}

static int buf_len (lua_State *L) {
	size_t l;
	luabuf_checkbuffer(L, 1, &l);
	lua_pushinteger(L, (lua_Integer)l);
	return 1;
}

static int buf_tostring (lua_State *L) {
	size_t l;
	const char *s = luabuf_checkbuffer(L, 1, &l);
	if (l>0) lua_pushlstring(L, s, l);
	else lua_pushliteral(L, "");
	return 1;
}

static int buf_get (lua_State *L) {
	size_t l;
	const char *s = luabuf_checkbuffer(L, 1, &l);
	return luastreamI_str2byte(L, s, l);
}

static int buf_set (lua_State *L) {
	size_t l;
	int n = lua_gettop(L)-2;  /* number of bytes */
	char *p = luabuf_checkbuffer(L, 1, &l);
	lua_Integer i = luastreamI_posrelat(luaL_checkinteger(L, 2), l);
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)l, 2, "index out of bounds");
	l = 1+l-i;
	luastreamI_code2char(L, 3, p+i-1, n<l ? n : l);
	return 0;
}

static int buf_fill (lua_State *L) {
	size_t l, sl;
	char *p = luabuf_checkbuffer(L, 1, &l);
	const char *s = luabuf_checkstream(L, 2, &sl);
	lua_Integer i = luastreamI_posrelat(luaL_optinteger(L, 3, 1), l);
	lua_Integer j = luastreamI_posrelat(luaL_optinteger(L, 4, -1), l);
	lua_Integer os = luastreamI_posrelat(luaL_optinteger(L, 5, 1), sl);
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)l, 3, "index out of bounds");
	luaL_argcheck(L, 1 <= j && j <= (lua_Integer)l, 4, "index out of bounds");
	if (os < 1) os = 1;
	if (i <= j && os <= (lua_Integer)sl) {
		int n = (int)(j - i + 1);
		if (i + n <= j)  /* arithmetic overflow? */
			return luaL_error(L, "string slice too long");
		--os;
		s += os;
		sl -= os;
		do {
			size_t sz = n < sl ? n : sl;
			memcpy(p+i-1, s, sz * sizeof(char));
			i += sz;
			n -= sz;
		} while (i <= j);
	}
	return 0;
}



static const luaL_Reg buflib[] = {
	{"create", buf_create},
	{"fill", buf_fill},
	{"get", buf_get},
	{"len", buf_len},
	{"set", buf_set},
	//{"pack", buf_pack},
	//{"unpack", buf_unpack},
	{NULL, NULL}
};

static const luaL_Reg bufmeta[] = {
	{"__len", buf_len},
	{"__tostring", buf_tostring},
	{NULL, NULL}
};


static void createmetatable (lua_State *L) {
	if (!luaL_getmetatable(L, LUABUF_BUFFER)) {
		lua_pop(L, 1);  /* pop 'nil' */
		luaL_newmetatable(L, LUABUF_BUFFER);
	}
	luaL_setfuncs(L, bufmeta, 0);  /* add buffer methods to new metatable */
	lua_pop(L, 1);  /* pop new metatable */
}


LUABUFMOD_API int luaopen_buffer (lua_State *L) {
	luaL_newlib(L, buflib);
	createmetatable(L);
	return 1;
}
