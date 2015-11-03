/*
** $Id$
** Lua Stream - Generic stream support for the Lua language
** Renato Maia, Tecgraf/PUC-Rio (http://www.tecgraf.puc-rio.br/~maia)
** See Copyright Notice at the end of this file
*/


#ifndef luastreamaux_h
#define luastreamaux_h


#include "lua.h"
#include "lauxlib.h"



#ifndef LUASTREAMLIB_API
#define LUASTREAMLIB_API LUALIB_API
#endif



/*
** A buffer is a userdata with metatable 'LUASTREAM_BUFFER'.
*/

#define LUASTREAM_BUFFER	"char*"


#define luastream_isbuffer(L,I)	(luaL_testudata (L,I,LUASTREAM_BUFFER) != NULL)


LUASTREAMLIB_API char *      (luastream_newbuffer) (lua_State *L, size_t len);
LUASTREAMLIB_API int         (luastream_isstream) (lua_State *L, int idx);
LUASTREAMLIB_API char *      (luastream_tobuffer) (lua_State *L, int idx, size_t *len);
LUASTREAMLIB_API const char *(luastream_tostream) (lua_State *L, int idx, size_t *len);
LUASTREAMLIB_API char *      (luastream_checkbuffer) (lua_State *L, int arg, size_t *len);
LUASTREAMLIB_API const char *(luastream_checkstream) (lua_State *L, int arg, size_t *len);

/*
** {======================================================
** Lua stack's buffer support
** =======================================================
*/

#define luastream_Buffer	luaL_Buffer
#define luastream_addchar	luaL_addchar
#define luastream_addsize	luaL_addsize
#define luastream_prepbuffsize	luaL_prepbuffsize
#define luastream_prepbuffer	luaL_prepbuffer
#define luastream_addstream	luaL_addlstring
#define luastream_addlstring	luaL_addlstring
#define luastream_addstring	luaL_addstring
#define luastream_pushresult	luaL_pushresult
#define luastream_pushresultsize	luaL_pushresultsize
#define luastream_buffinit	luaL_buffinit
#define luastream_buffinitsize	luaL_buffinitsize


LUASTREAMLIB_API void (luastream_addvalue) (luastream_Buffer *B);
LUASTREAMLIB_API void (luastream_pushresbuf) (luastream_Buffer *B);
LUASTREAMLIB_API void (luastream_pushresbufsize) (luastream_Buffer *B, size_t sz);

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
