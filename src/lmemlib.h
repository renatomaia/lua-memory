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


#define LUAMEM_TNONE	0
#define LUAMEM_TALLOC	1
#define LUAMEM_TREF	2

#define LUAMEM_ALLOC	"char[]"
#define LUAMEM_REF	"luamem_Ref"


LUAMEMLIB_API char *(luamem_newalloc) (lua_State *L, size_t len);


typedef void (*luamem_Unref) (lua_State *L, void *mem, size_t len);

#define luamem_isref(L,I)	(luaL_testudata(L,I,LUAMEM_REF) != NULL)

LUAMEMLIB_API void (luamem_newref) (lua_State *L);
LUAMEMLIB_API int (luamem_setref) (lua_State *L, int idx,
                                   char *mem, size_t len, luamem_Unref unref);


#define luamem_tomemory(L,I,S)	(luamem_tomemoryx(L,I,S,NULL,NULL))

LUAMEMLIB_API int (luamem_ismemory) (lua_State *L, int idx);
LUAMEMLIB_API char *(luamem_tomemoryx) (lua_State *L, int idx,
                                        size_t *len, luamem_Unref *unref,
                                        int *type);
LUAMEMLIB_API char *(luamem_checkmemory) (lua_State *L, int idx, size_t *len);


LUAMEMLIB_API int (luamem_isstring) (lua_State *L, int idx);
LUAMEMLIB_API const char *(luamem_tostring) (lua_State *L, int idx, size_t *len);
LUAMEMLIB_API const char *(luamem_checkstring) (lua_State *L, int idx, size_t *len);
LUAMEMLIB_API const char *(luamem_optstring) (lua_State *L, int arg, const char *def, size_t *len);


LUAMEMLIB_API void *(luamem_realloc) (lua_State *L, void *mem, size_t osize,
                                                               size_t nsize);
LUAMEMLIB_API void (luamem_free) (lua_State *L, void *memo, size_t size);
LUAMEMLIB_API size_t (luamem_checklenarg) (lua_State *L, int idx);


/*
** Some sizes are better limited to fit in 'int', but must also fit in
** 'size_t'. (We assume that 'lua_Integer' cannot be smaller than 'int'.)
*/
#define LUAMEM_MAXALLOC  \
	(sizeof(size_t) < sizeof(int) ? (~(size_t)0) : (size_t)(INT_MAX))


/*
** {======================================================
** Lua stack's buffer support
** =======================================================
*/

LUAMEMLIB_API void (luamem_addvalue) (luaL_Buffer *B);
LUAMEMLIB_API void (luamem_pushresult) (luaL_Buffer *B);
LUAMEMLIB_API void (luamem_pushresultsize) (luaL_Buffer *B, size_t sz);

/* }====================================================== */


#endif
