/*
** $Id$
** Auxiliary functions for handling generic streams in Lua.
** See Copyright Notice in lstraux.h
*/

#define lstraux_c
#define LUABUFLIB_API

#include "lstraux.h"

#include <string.h>



LUABUFLIB_API char *luabuf_newbuffer (lua_State *L, size_t l) {
	char *p = lua_newuserdata(L, l * sizeof(char));
	if (!luaL_getmetatable(L, LUABUF_BUFFER)) {
		lua_pop(L, 1);  /* pop 'nil' */
		luaL_newmetatable(L, LUABUF_BUFFER);
	}
	lua_setmetatable(L, -2);
	return p;
}


LUABUFLIB_API char *luabuf_tobuffer (lua_State *L, int idx, size_t *len) {
	char *b = luaL_testudata(L, idx, LUABUF_BUFFER);
	if (b && len) *len = lua_rawlen(L, idx);
	return b;
}


LUABUFLIB_API int luabuf_isstream (lua_State *L, int idx) {
	return (lua_isstring(L, idx) || luabuf_isbuffer(L, idx));
}


LUABUFLIB_API const char *luabuf_tostream (lua_State *L, int idx, size_t *len) {
	if (lua_isstring(L, idx)) return lua_tolstring(L, idx, len);
	return luabuf_tobuffer(L, idx, len);
}


LUABUFLIB_API char *luabuf_checkbuffer (lua_State *L, int idx, size_t *len) {
	char *b = luaL_checkudata(L, idx, LUABUF_BUFFER);
	if (len) *len = lua_rawlen(L, idx);
	return b;
}


LUABUFLIB_API const char *luabuf_checkstream (lua_State *L, int arg, size_t *len) {
  const char *s = luabuf_tostream(L, arg, len);
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


LUABUFLIB_API void luabuf_pushresbuf (luabuf_Buffer *B) {
	lua_State *L = B->L;
	if (!buffonstack(B) || B->n < B->size) {
		char *p = (char *)luabuf_newbuffer(L, B->n * sizeof(char));
		/* move content to new buffer */
		memcpy(p, B->b, B->n * sizeof(char));
		if (buffonstack(B))
			lua_remove(L, -2);  /* remove old buffer */
	}
}


LUABUFLIB_API void luabuf_pushresbufsize (luabuf_Buffer *B, size_t sz) {
	luaL_addsize(B, sz);
	luabuf_pushresbuf(B);
}


LUABUFLIB_API void luabuf_addvalue (luabuf_Buffer *B) {
	lua_State *L = B->L;
	size_t l;
	const char *s = luabuf_tostream(L, -1, &l);
	if (buffonstack(B))
		lua_insert(L, -2);  /* put value below buffer */
	luabuf_addstream(B, s, l);
	lua_remove(L, (buffonstack(B)) ? -2 : -1);  /* remove value */
}

/* }====================================================== */
