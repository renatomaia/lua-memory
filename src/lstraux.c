/*
** $Id$
** Auxiliary functions for handling generic streams in Lua.
** See Copyright Notice in lstraux.h
*/

#define lstraux_c
#define LUASTREAMLIB_API

#include "lstraux.h"

#include <string.h>



LUASTREAMLIB_API char *luastream_newbuffer (lua_State *L, size_t l) {
	char *p = lua_newuserdata(L, l * sizeof(char));
	if (!luaL_getmetatable(L, LUASTREAM_BUFFER)) {
		lua_pop(L, 1);  /* pop 'nil' */
		luaL_newmetatable(L, LUASTREAM_BUFFER);
	}
	lua_setmetatable(L, -2);
	return p;
}


LUASTREAMLIB_API char *luastream_tobuffer (lua_State *L, int idx, size_t *len) {
	char *b = luaL_testudata(L, idx, LUASTREAM_BUFFER);
	if (b && len) *len = lua_rawlen(L, idx);
	return b;
}


LUASTREAMLIB_API int luastream_isstream (lua_State *L, int idx) {
	return (lua_isstring(L, idx) || luastream_isbuffer(L, idx));
}


LUASTREAMLIB_API const char *luastream_tostream (lua_State *L, int idx, size_t *len) {
	if (lua_isstring(L, idx)) return lua_tolstring(L, idx, len);
	return luastream_tobuffer(L, idx, len);
}


LUASTREAMLIB_API char *luastream_checkbuffer (lua_State *L, int idx, size_t *len) {
	char *b = luaL_checkudata(L, idx, LUASTREAM_BUFFER);
	if (len) *len = lua_rawlen(L, idx);
	return b;
}


LUASTREAMLIB_API const char *luastream_checkstream (lua_State *L, int arg, size_t *len) {
  const char *s = luastream_tostream(L, arg, len);
  if (!s) luaL_argerror(L, arg, "stream expected");
  return s;
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
#define buffonstack(B)	((B)->b != (B)->initb)


LUASTREAMLIB_API void luastream_pushresbuf (luastream_Buffer *B) {
	lua_State *L = B->L;
	if (!buffonstack(B) || B->n < B->size) {
		char *p = (char *)luastream_newbuffer(L, B->n * sizeof(char));
		/* move content to new buffer */
		memcpy(p, B->b, B->n * sizeof(char));
		if (buffonstack(B))
			lua_remove(L, -2);  /* remove old buffer */
	}
}


LUASTREAMLIB_API void luastream_pushresbufsize (luastream_Buffer *B, size_t sz) {
	luaL_addsize(B, sz);
	luastream_pushresbuf(B);
}


LUASTREAMLIB_API void luastream_addvalue (luastream_Buffer *B) {
	lua_State *L = B->L;
	size_t l;
	const char *s = luastream_tostream(L, -1, &l);
	if (buffonstack(B))
		lua_insert(L, -2);  /* put value below buffer */
	luastream_addstream(B, s, l);
	lua_remove(L, (buffonstack(B)) ? -2 : -1);  /* remove value */
}

/* }====================================================== */
