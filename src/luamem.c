#define luamem_c
#define LUA_LIB
#define LUAMEMLIB_API

#include "luamem.h"

#include <string.h>


LUAMEMLIB_API char *luamem_newalloc (lua_State *L, size_t l) {
	char *mem = (char *)lua_newuserdatauv(L, l * sizeof(char), 0);
	luaL_newmetatable(L, LUAMEM_ALLOC);
	lua_setmetatable(L, -2);
	return mem;
}

typedef struct luamem_Ref {
	char *mem;
	size_t len;
	luamem_Unref unref;
} luamem_Ref;

#define unrefmem(L,r)	if (r->unref) ref->unref(L, r->mem, r->len)

static int refgc (lua_State *L) {
	luamem_Ref *ref = (luamem_Ref *)lua_touserdata(L, 1);
	if (ref && ref->len) {
		unrefmem(L, ref);
		ref->mem = NULL;
		ref->len = 0;
		ref->unref = NULL;
	}
	return 0;
}

static const luaL_Reg refmt[] = {  /* metamethods */
	{"__gc", refgc},
	{"__close", refgc},
	{NULL, NULL}
};

LUAMEMLIB_API void luamem_newref (lua_State *L) {
	luamem_Ref *ref = (luamem_Ref *)lua_newuserdatauv(L, sizeof(luamem_Ref), 0);
	ref->mem = NULL;
	ref->len = 0;
	ref->unref = NULL;
	if (luaL_newmetatable(L, LUAMEM_REF)) luaL_setfuncs(L, refmt, 0);
	lua_setmetatable(L, -2);
}

LUAMEMLIB_API int luamem_resetref (lua_State *L, int idx, 
                                   char *mem, size_t len, luamem_Unref unref,
                                   int cleanup) {
	luamem_Ref *ref = (luamem_Ref *)luaL_testudata(L, idx, LUAMEM_REF);
	if (ref) {
		if (mem != ref->mem) {
			if (cleanup) unrefmem(L, ref);
			ref->mem = mem;
		}
		ref->len = len;
		ref->unref = unref;
		return 1;
	}
	return 0;
}

LUAMEMLIB_API int luamem_type (lua_State *L, int idx) {
	int type = LUAMEM_TNONE;
	if (lua_type(L, idx) == LUA_TUSERDATA) {
		if (lua_getmetatable(L, idx)) {  /* does it have a metatable? */
			luaL_getmetatable(L, LUAMEM_ALLOC);  /* get allocated memory metatable */
			if (lua_rawequal(L, -1, -2)) type = LUAMEM_TALLOC;
			else {
				lua_pop(L, 1);  /* remove allocated memory metatable */
				luaL_getmetatable(L, LUAMEM_REF);  /* get referenced memory metatable */
				if (lua_rawequal(L, -1, -2)) type = LUAMEM_TREF;
			}
			lua_pop(L, 2);  /* remove both metatables */
		}
	}
	return type;
}

LUAMEMLIB_API char *luamem_tomemoryx (lua_State *L, int idx,
                                      size_t *len, luamem_Unref *unref,
                                      int *type) {
	int typemem;
	if (!type) type = &typemem;
	*type = luamem_type(L, idx);
	switch (*type) {
		case LUAMEM_TALLOC:
			if (len) *len = lua_rawlen(L, idx);
			if (unref) *unref = NULL;
			return (char *)lua_touserdata(L, idx);
		case LUAMEM_TREF: {
			luamem_Ref *ref = (luamem_Ref *)lua_touserdata(L, idx);
			if (len) *len = ref->len;
			if (unref) *unref = ref->unref;
			return ref->mem;
		}
	}
	if (len) *len = 0;
	if (unref) *unref = NULL;
	return NULL;
}

LUAMEMLIB_API char *luamem_checkmemory (lua_State *L, int arg, size_t *len) {
	int type;
	char *mem = luamem_tomemoryx(L, arg, len, NULL, &type);
	if (type == LUAMEM_TNONE) luaL_typeerror(L, arg, "memory");
	return mem;
}


LUAMEMLIB_API int luamem_isarray (lua_State *L, int idx) {
	return (lua_isstring(L, idx) || luamem_ismemory(L, idx));
}

LUAMEMLIB_API const char *luamem_toarray (lua_State *L, int idx, size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, idx, len, NULL, &type);
	if (type == LUAMEM_TNONE) return lua_tolstring(L, idx, len);
	return s;
}

LUAMEMLIB_API const char *luamem_asarray (lua_State *L, int idx, size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, idx, len, NULL, &type);
	if (type == LUAMEM_TNONE) return luaL_tolstring(L, idx, len);
	return s;
}

LUAMEMLIB_API const char *luamem_checkarray (lua_State *L,
                                             int arg,
                                             size_t *len) {
	int type;
	const char *s = luamem_tomemoryx(L, arg, len, NULL, &type);
	if (type == LUAMEM_TNONE) {
		s = lua_tolstring(L, arg, len);
		if (!s) luaL_typeerror(L, arg, "string or memory");
	}
	return s;
}

LUAMEMLIB_API const char *luamem_optarray (lua_State *L,
                                           int arg,
                                           const char *def,
                                           size_t *len) {
	if (lua_isnoneornil(L, arg)) {
		if (len)
			*len = (def ? strlen(def) : 0);
		return def;
	}
	else return luamem_checkarray(L, arg, len);
}


LUAMEMLIB_API void *luamem_realloc(lua_State *L, void *mem, size_t osize,
                                                            size_t nsize) {
	void *userdata;
	lua_Alloc alloc = lua_getallocf(L, &userdata);
	return alloc(userdata, mem, osize, nsize);
}

LUAMEMLIB_API void luamem_free(lua_State *L, void *mem, size_t size) {
	luamem_realloc(L, mem, size, 0);
}

LUAMEMLIB_API size_t luamem_checklenarg (lua_State *L, int idx) {
	lua_Integer sz = luaL_checkinteger(L, idx);
	luaL_argcheck(L, 0 <= sz && sz < (lua_Integer)LUAMEM_MAXSIZE,
	                 idx, "invalid size");
	return (size_t)sz;
}

/*
* NOTE: most of the code below is copied from the source of Lua 5.4.3 by
*       R. Ierusalimschy, L. H. de Figueiredo, W. Celes - Lua.org, PUC-Rio.
*
* Copyright (C) 1994-2020 Lua.org, PUC-Rio.
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
*/

/*
** {======================================================
** Generic Buffer manipulation
** =======================================================
*/


/* userdata to box arbitrary data */
typedef struct UBox {
	void *box;
	size_t bsize;
} UBox;


static void *resizebox (lua_State *L, int idx, size_t newsize) {
	void *ud;
	lua_Alloc allocf = lua_getallocf(L, &ud);
	UBox *box = (UBox *)lua_touserdata(L, idx);
	void *temp = allocf(ud, box->box, box->bsize, newsize);
	if (l_unlikely(temp == NULL && newsize > 0)) {  /* allocation error? */
		lua_pushliteral(L, "not enough memory");
		lua_error(L);  /* raise a memory error */
	}
	box->box = temp;
	box->bsize = newsize;
	return temp;
}


static int boxgc (lua_State *L) {
	resizebox(L, 1, 0);
	return 0;
}


static const luaL_Reg boxmt[] = {  /* box metamethods */
	{"__gc", boxgc},
	{"__close", boxgc},
	{NULL, NULL}
};


static void newbox (lua_State *L) {
	UBox *box = (UBox *)lua_newuserdatauv(L, sizeof(UBox), 0);
	box->box = NULL;
	box->bsize = 0;
	if (luaL_newmetatable(L, "_UBOX*"))  /* creating metatable? */
		luaL_setfuncs(L, boxmt, 0);  /* set its metamethods */
	lua_setmetatable(L, -2);
}


/*
** check whether buffer is using a userdata on the stack as a temporary
** buffer
*/
#define buffonstack(B)	((B)->b != (B)->init.b)


/*
** Whenever buffer is accessed, slot 'idx' must either be a box (which
** cannot be NULL) or it is a placeholder for the buffer.
*/
#define checkbufferlevel(B,idx)  \
	lua_assert(buffonstack(B) ? lua_touserdata(B->L, idx) != NULL  \
		                        : lua_touserdata(B->L, idx) == (void*)B)


/*
** Compute new size for buffer 'B', enough to accommodate extra 'sz'
** bytes.
*/
static size_t newbuffsize (luaL_Buffer *B, size_t sz) {
	size_t newsize = B->size * 2;  /* double buffer size */
	if (l_unlikely(MAX_SIZET - sz < B->n))  /* overflow in (B->n + sz)? */
		return luaL_error(B->L, "buffer too large");
	if (newsize < B->n + sz)  /* double is not big enough? */
		newsize = B->n + sz;
	return newsize;
}


/*
** Returns a pointer to a free area with at least 'sz' bytes in buffer
** 'B'. 'boxidx' is the relative position in the stack where is the
** buffer's box or its placeholder.
*/
static char *prepbuffsize (luaL_Buffer *B, size_t sz, int boxidx) {
	checkbufferlevel(B, boxidx);
	if (B->size - B->n >= sz)  /* enough space? */
		return B->b + B->n;
	else {
		lua_State *L = B->L;
		char *newbuff;
		size_t newsize = newbuffsize(B, sz);
		/* create larger buffer */
		if (buffonstack(B))  /* buffer already has a box? */
			newbuff = (char *)resizebox(L, boxidx, newsize);  /* resize it */
		else {  /* no box yet */
			lua_remove(L, boxidx);  /* remove placeholder */
			newbox(L);  /* create a new box */
			lua_insert(L, boxidx);  /* move box to its intended position */
			lua_toclose(L, boxidx);
			newbuff = (char *)resizebox(L, boxidx, newsize);
			memcpy(newbuff, B->b, B->n * sizeof(char));  /* copy original content */
		}
		B->b = newbuff;
		B->size = newsize;
		return newbuff + B->n;
	}
}


LUAMEMLIB_API void luamem_addvalue (luaL_Buffer *B) {
	lua_State *L = B->L;
	size_t len;
	const char *s = luamem_toarray(L, -1, &len);
	char *b = prepbuffsize(B, len, -2);
	memcpy(b, s, len * sizeof(char));
	luaL_addsize(B, len);
	lua_pop(L, 1);  /* pop string */
}

/* }====================================================== */
