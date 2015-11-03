/*
** $Id$
** Stream support for the Lua language
** See Copyright Notice in lstraux.h
*/

#ifndef lstrops_h
#define lstrops_h


#include <lua.h>



#ifndef LUASTREAM_FUNC
#define LUASTREAM_FUNC LUAI_FUNC
#endif



/*
** Some sizes are better limited to fit in 'int', but must also fit in
** 'size_t'. (We assume that 'lua_Integer' cannot be smaller than 'int'.)
*/
#define LUASTREAM_MAXSIZE  \
	(sizeof(size_t) < sizeof(int) ? (~(size_t)0) : (size_t)(INT_MAX))




LUASTREAM_FUNC lua_Integer luastreamI_posrelat (lua_Integer pos, size_t len);
LUASTREAM_FUNC int luastreamI_str2byte (lua_State *L, const char *s, size_t l);
LUASTREAM_FUNC void luastreamI_code2char (lua_State *L, int idx, char *p, int n);


#endif
