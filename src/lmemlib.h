/*
** $Id$
** Lua Stream - Generic stream support for the Lua language
** Renato Maia, Tecgraf/PUC-Rio (http://www.tecgraf.puc-rio.br/~maia)
** See Copyright Notice at the end of this file
*/


#ifndef lstraux_h
#define lstraux_h


#include <lua.h>
#include <lauxlib.h>



#ifndef LUAMEMLIB_API
#define LUAMEMLIB_API LUALIB_API
#endif

#ifndef LUAMEMMOD_API
#define LUAMEMMOD_API LUAMOD_API
#endif



#define LUAMEM_ALLOC	"char[]"
#define LUAMEM_REF	"luamem_Ref"


typedef void (*luamem_Unref) (char *mem, size_t len);

typedef struct luamem_Ref {
	size_t len;
	luamem_Unref unref;
	/* private part */
	char *memory;
} luamem_Ref;


#define luamem_toref(L,I)	(luaL_testudata(L,I,LUAMEM_REF))
#define luamem_isref(L,I)	(luamem_toref(L,I) != NULL)
#define luamem_isalloc(L,I)	(luaL_testudata(L,I,LUAMEM_ALLOC) != NULL)
#define luamem_ismemory(L,I)	(luaL_tomemory(L,I,NULL) != NULL)


LUAMEMLIB_API char *      (luamem_newalloc) (lua_State *L, size_t len);

LUAMEMLIB_API void        (luamem_pushrefmt) (lua_State *L);
LUAMEMLIB_API luamem_Ref *(luamem_pushref) (lua_State *L, char *mem);
LUAMEMLIB_API luamem_Ref *(luamem_getref) (lua_State *L, char *mem);
LUAMEMLIB_API luamem_Ref *(luamem_toref) (lua_State *L, int idx);

LUAMEMLIB_API char *      (luamem_tomemory) (lua_State *L, int idx, size_t *len);
LUAMEMLIB_API char *      (luamem_checkmemory) (lua_State *L, int idx, size_t *len);

LUAMEMLIB_API int         (luamem_isstring) (lua_State *L, int idx);
LUAMEMLIB_API const char *(luamem_tostring) (lua_State *L, int idx, size_t *len);
LUAMEMLIB_API const char *(luamem_checkstring) (lua_State *L, int idx, size_t *len);


/*
** Some sizes are better limited to fit in 'int', but must also fit in
** 'size_t'. (We assume that 'lua_Integer' cannot be smaller than 'int'.)
*/
#define LUABUF_MAXSIZE  \
	(sizeof(size_t) < sizeof(int) ? (~(size_t)0) : (size_t)(INT_MAX))

LUAMEMLIB_API lua_Integer luamem_posrelat (lua_Integer pos, size_t len);
LUAMEMLIB_API int luamem_str2byte (lua_State *L, const char *s, size_t l);
LUAMEMLIB_API void luamem_code2char (lua_State *L, int idx, char *p, int n);


/*
** {======================================================
** Lua stack's buffer support
** =======================================================
*/

#define luamem_Buffer	luaL_Buffer
#define luamem_addchar	luaL_addchar
#define luamem_addsize	luaL_addsize
#define luamem_prepbuffsize	luaL_prepbuffsize
#define luamem_prepbuffer	luaL_prepbuffer
#define luamem_addlstring	luaL_addlstring
#define luamem_addstring	luaL_addstring
#define luamem_pushresult	luaL_pushresult
#define luamem_pushresultsize	luaL_pushresultsize
#define luamem_buffinit	luaL_buffinit
#define luamem_buffinitsize	luaL_buffinitsize


LUAMEMLIB_API void (luamem_addvalue) (luamem_Buffer *B);
LUAMEMLIB_API void (luamem_pushresbuf) (luamem_Buffer *B);
LUAMEMLIB_API void (luamem_pushresbufsize) (luamem_Buffer *B, size_t sz);

/* }====================================================== */


#endif
