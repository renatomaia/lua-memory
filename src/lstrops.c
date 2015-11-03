/*
** $Id$
** NOTE: most of the code in here is copied from the source of Lua 5.3.1 by
**       R. Ierusalimschy, L. H. de Figueiredo, W. Celes - Lua.org, PUC-Rio.
**
** Stream support for the Lua language
** See Copyright Notice in lstraux.h
*/

#define lstrops_c

#include "lstraux.h"
#include "lstrops.h"


/* macro to 'unsign' a character */
#define uchar(c)	((unsigned char)(c))


/* translate a relative string position: negative means back from end */
LUABUF_FUNC lua_Integer luastreamI_posrelat (lua_Integer pos, size_t len) {
	if (pos >= 0) return pos;
	else if (0u - (size_t)pos > len) return 0;
	else return (lua_Integer)len + pos + 1;
}

LUABUF_FUNC int luastreamI_str2byte (lua_State *L, const char *s, size_t l) {
	lua_Integer posi = luastreamI_posrelat(luaL_optinteger(L, 2, 1), l);
	lua_Integer pose = luastreamI_posrelat(luaL_optinteger(L, 3, posi), l);
	int n, i;
	if (posi < 1) posi = 1;
	if (pose > (lua_Integer)l) pose = l;
	if (posi > pose) return 0;  /* empty interval; return no values */
	n = (int)(pose - posi + 1);
	if (posi + n <= pose)  /* arithmetic overflow? */
		return luaL_error(L, "string slice too long");
	luaL_checkstack(L, n, "string slice too long");
	for (i=0; i<n; i++)
		lua_pushinteger(L, uchar(s[posi+i-1]));
	return n;
}

LUABUF_FUNC void luastreamI_code2char (lua_State *L, int idx, char *p, int n) {
	int i;
	for (i=0; i<n; ++i, ++idx) {
		lua_Integer c = luaL_checkinteger(L, idx);
		luaL_argcheck(L, uchar(c) == c, idx, "value out of range");
		p[i] = uchar(c);
	}
}
