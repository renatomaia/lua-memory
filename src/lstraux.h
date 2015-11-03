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



#ifndef LUABUFLIB_API
#define LUABUFLIB_API LUALIB_API
#endif

#ifndef LUABUFMOD_API
#define LUABUFMOD_API LUAMOD_API
#endif



/*
** A buffer is a userdata with metatable 'LUABUF_BUFFER'.
*/

#define LUABUF_BUFFER	"char*"


#define luabuf_isbuffer(L,I)	(luaL_testudata (L,I,LUABUF_BUFFER) != NULL)


LUABUFLIB_API char *      (luabuf_newbuffer) (lua_State *L, size_t len);
LUABUFLIB_API int         (luabuf_isstream) (lua_State *L, int idx);
LUABUFLIB_API char *      (luabuf_tobuffer) (lua_State *L, int idx, size_t *len);
LUABUFLIB_API const char *(luabuf_tostream) (lua_State *L, int idx, size_t *len);
LUABUFLIB_API char *      (luabuf_checkbuffer) (lua_State *L, int arg, size_t *len);
LUABUFLIB_API const char *(luabuf_checkstream) (lua_State *L, int arg, size_t *len);

/*
** {======================================================
** Lua stack's buffer support
** =======================================================
*/

#define luabuf_Buffer	luaL_Buffer
#define luabuf_addchar	luaL_addchar
#define luabuf_addsize	luaL_addsize
#define luabuf_prepbuffsize	luaL_prepbuffsize
#define luabuf_prepbuffer	luaL_prepbuffer
#define luabuf_addstream	luaL_addlstring
#define luabuf_addlstring	luaL_addlstring
#define luabuf_addstring	luaL_addstring
#define luabuf_pushresult	luaL_pushresult
#define luabuf_pushresultsize	luaL_pushresultsize
#define luabuf_buffinit	luaL_buffinit
#define luabuf_buffinitsize	luaL_buffinitsize


LUABUFLIB_API void (luabuf_addvalue) (luabuf_Buffer *B);
LUABUFLIB_API void (luabuf_pushresbuf) (luabuf_Buffer *B);
LUABUFLIB_API void (luabuf_pushresbufsize) (luabuf_Buffer *B, size_t sz);

/* }====================================================== */


/******************************************************************************
* Copyright (C) 1994-2015 Lua.org, PUC-Rio.
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
******************************************************************************/


#endif
