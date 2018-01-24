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


LUAMEMLIB_API char *(luamem_newalloc) (lua_State *L, size_t len);


typedef void (*luamem_Unref) (lua_State *L, void *mem, size_t len);

#define luamem_isref(L,I)	(luaL_testudata(L,I,LUAMEM_REF) != NULL)

LUAMEMLIB_API void (luamem_newref) (lua_State *L);
LUAMEMLIB_API int (luamem_setref) (lua_State *L, int idx, char *mem, size_t len, luamem_Unref unref);


#define luamem_ismemory(L,I)	(luamem_tomemory(L,I,NULL) != NULL)
#define luamem_tomemory(L,I,S)	(luamem_tomemoryx(L,I,S,NULL))

LUAMEMLIB_API char *(luamem_tomemoryx) (lua_State *L, int idx, size_t *len, int *isref);
LUAMEMLIB_API char *(luamem_checkmemory) (lua_State *L, int idx, size_t *len);


LUAMEMLIB_API int (luamem_isstring) (lua_State *L, int idx);
LUAMEMLIB_API const char *(luamem_tostring) (lua_State *L, int idx, size_t *len);
LUAMEMLIB_API const char *(luamem_checkstring) (lua_State *L, int idx, size_t *len);


LUAMEMLIB_API void *(luamem_realloc) (lua_State *L, void *mem, size_t old,
                                                               size_t new);
LUAMEMLIB_API void (luamem_free) (lua_State *L, void *memo, size_t size);
LUAMEMLIB_API size_t (luamem_checklenarg) (lua_State *L, int idx);


/*
** Some sizes are better limited to fit in 'int', but must also fit in
** 'size_t'. (We assume that 'lua_Integer' cannot be smaller than 'int'.)
*/
#define LUAMEM_MAXALLOC  \
	(sizeof(size_t) < sizeof(int) ? (~(size_t)0) : (size_t)(INT_MAX))

LUAMEMLIB_API lua_Integer (luamem_posrelat) (lua_Integer pos, size_t len);
LUAMEMLIB_API int (luamem_str2byte) (lua_State *L, const char *s, size_t l);
LUAMEMLIB_API void (luamem_code2char) (lua_State *L, int idx, char *p, int n);


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
