#define lmemmod_c

#include "lmemlib.h"

#include <ctype.h>
#include <locale.h>
#include <string.h>
#include <lualib.h>

static lua_Integer posrelat (lua_Integer pos, size_t len);
static int str2byte (lua_State *L, const char *s, size_t l);
static void code2char (lua_State *L, int idx, char *p, lua_Integer n);
static const char *lmemfind (const char *s1, size_t l1,
                             const char *s2, size_t l2);

static int mem_create (lua_State *L) {
	if (lua_gettop(L) == 0) {
		luamem_newref(L);
		luamem_setref(L, 1, NULL, 0, luamem_free);
	} else {
		char *p;
		size_t len;
		const char *s = NULL;
		if (lua_type(L, 1) == LUA_TNUMBER) {
			len = luamem_checklenarg(L, 1);
		} else {
			lua_Integer posi, pose;
			s = luamem_checkstring(L, 1, &len);
			posi = posrelat(luaL_optinteger(L, 2, 1), len);
			pose = posrelat(luaL_optinteger(L, 3, -1), len);
			if (posi < 1) posi = 1;
			if (pose > (lua_Integer)len) pose = len;
			if (posi > pose) {
				len = 0;
				s = NULL;
			} else {
				if (pose - posi >= INT_MAX)  /* arithmetic overflow? */
					return luaL_error(L, "string slice too long");
				len = (pose - posi) + 1;
				s += posi-1;
			}
		}
		p = luamem_newalloc(L, len);
		if (s) memcpy(p, s, len*sizeof(char));
		else memset(p, 0, len*sizeof(char));
	}
	return 1;
}

static void memfill (char *mem, size_t size, const char *s, size_t len) {
	do {
		size_t n = size < len ? size : len;
		memmove(mem, s, n * sizeof(char));
		mem += n;
		size -= n;
	} while (size > 0);
}

static int mem_resize (lua_State *L) {
	size_t len;
	luamem_Unref unref;
	char *mem = luamem_tomemoryx(L, 1, &len, &unref, NULL);
	size_t size = luamem_checklenarg(L, 2);
	luaL_argcheck(L, unref == luamem_free, 1, "resizable memory expected");
	if (len != size) {
		size_t sl, n = len < size ? size-len : 0;
		const char *s = luamem_optstring(L, 3, NULL, &sl);
		char *resized = (char *)luamem_realloc(L, mem, len, size);
		if (size && !resized) luaL_error(L, "out of memory");
		luamem_setref(L, 1, mem, len, NULL);  /* don't free `mem` again */
		luamem_setref(L, 1, resized, size, luamem_free);
		if (n) {
			resized += len;
			if (sl) memfill(resized, n, s, sl);
			else memset(resized, 0, n*sizeof(char));
		}
	}
	return 0;
}

static int mem_type (lua_State *L) {
	luamem_Unref unref;
	int type;
	luamem_tomemoryx(L, 1, NULL, &unref, &type);
	if (type == LUAMEM_TALLOC) {
		lua_pushliteral(L, "fixed");
	} else if (type == LUAMEM_TREF) {
		if (unref == luamem_free) lua_pushliteral(L, "resizable");
		else lua_pushliteral(L, "other");
	} else {
		lua_pushnil(L);
	}
	return 1;
}

static int mem_len (lua_State *L) {
	size_t len;
	luamem_checkmemory(L, 1, &len);
	lua_pushinteger(L, (lua_Integer)len);
	return 1;
}

static int mem_tostring (lua_State *L) {
	size_t len;
	const char *s = luamem_checkstring(L, 1, &len);
	lua_Integer posi = posrelat(luaL_optinteger(L, 2, 1), len);
	lua_Integer pose = posrelat(luaL_optinteger(L, 3, -1), len);
	int n;
	if (posi < 1) posi = 1;
	if (pose > (lua_Integer)len) pose = len;
	n = (int)(pose - posi + 1);
	if (posi + n <= pose)  /* arithmetic overflow? */
		return luaL_error(L, "string slice too long");
	if (n > 0) lua_pushlstring(L, s + posi -1, n);
	else lua_pushliteral(L, "");
	return 1;
}

static int mem_diff (lua_State *L) {
	size_t l1, l2;
	const char *s1 = luamem_checkstring(L, 1, &l1);
	const char *s2 = luamem_checkstring(L, 2, &l2);
	size_t i, n=(l1<l2 ? l1 : l2);
	for (i=0; (i<n) && (s1[i]==s2[i]); ++i);
	if (i<n) {
		lua_pushinteger(L, i+1);
		lua_pushboolean(L, s1[i]<s2[i]);
	} else if (l1==l2) {
		lua_pushnil(L);
		lua_pushboolean(L, 0);
	} else {
		lua_pushinteger(L, i+1);
		lua_pushboolean(L, l1<l2);
	}
	return 2;
}

static int mem_get (lua_State *L) {
	size_t len;
	const char *s = luamem_checkmemory(L, 1, &len);
	return str2byte(L, s, len);
}

static int mem_set (lua_State *L) {
	size_t len;
	lua_Integer n = lua_gettop(L)-2;  /* number of bytes */
	char *p = luamem_checkmemory(L, 1, &len);
	lua_Integer i = posrelat(luaL_checkinteger(L, 2), len);
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)len, 2, "index out of bounds");
	len = 1+len-i;
	code2char(L, 3, p+i-1, n < (lua_Integer)len ? n : (lua_Integer)len);
	return 0;
}

static int mem_find (lua_State *L) {
	size_t len, sl;
	const char *p = luamem_checkstring(L, 1, &len);
	const char *s = luamem_checkstring(L, 2, &sl);
	lua_Integer i = posrelat(luaL_optinteger(L, 3, 1), len);
	lua_Integer j = posrelat(luaL_optinteger(L, 4, -1), len);
	lua_Integer os = posrelat(luaL_optinteger(L, 5, 1), sl);
	if (os < 1) os = 1;
	if (i <= j && os <= (lua_Integer)sl) {
		int n = (int)(j - i + 1);
		if (i + n <= j)  /* arithmetic overflow? */
			return luaL_error(L, "string slice too long");
		--os;
		sl -= os;
		s = lmemfind(p + i - 1, (size_t)n, s + os, sl);
		if (s) {
			lua_pushinteger(L, (s - p) + 1);
			lua_pushinteger(L, (s - p) + sl);
			return 2;
		}
	}
	return 0;
}

static int mem_fill (lua_State *L) {
	size_t len, sl;
	char *p = luamem_checkmemory(L, 1, &len);
	lua_Integer i = posrelat(luaL_optinteger(L, 3, 1), len);
	lua_Integer j = posrelat(luaL_optinteger(L, 4, -1), len);
	char c;
	const char *s = NULL;
	lua_Integer os;
	if (lua_type(L, 2) == LUA_TNUMBER) {
		s = &c;
		sl = 1;
		os = 1;
		code2char(L, 2, &c, 1);
	} else {
		s = luamem_checkstring(L, 2, &sl);
		os = posrelat(luaL_optinteger(L, 5, 1), sl);
	}
	if (os < 1) os = 1;
	if (i <= j && os <= (lua_Integer)sl) {
		size_t n = (size_t)(j-i+1);
		luaL_argcheck(L, 1 <= i && i <= (lua_Integer)len, 3, "index out of bounds");
		luaL_argcheck(L, 1 <= j && j <= (lua_Integer)len, 4, "index out of bounds");
		if (i+(lua_Integer)n <= j)  /* arithmetic overflow? */
			return luaL_error(L, "string slice too long");
		--os;
		memfill(p+i-1, n, s+os, sl-os);
	}
	return 0;
}

static int mem_format (lua_State *L);
static int mem_pack (lua_State *L);
static int mem_unpack (lua_State *L);

static const luaL_Reg lib[] = {
	{"create", mem_create},
	{"type", mem_type},
	{"resize", mem_resize},
	{"len", mem_len},
	{"diff", mem_diff},
	{"find", mem_find},
	{"fill", mem_fill},
	{"get", mem_get},
	{"set", mem_set},
	{"format", mem_format},
	{"pack", mem_pack},
	{"unpack", mem_unpack},
	{"tostring", mem_tostring},
	{NULL, NULL}
};

static const luaL_Reg meta[] = {
	{"__len", mem_len},
	{"__tostring", mem_tostring},
	{NULL, NULL}
};


static void setupmetatable (lua_State *L) {
	if (lua_getmetatable(L, -1)) {
		luaL_setfuncs(L, meta, 0);  /* add metamethods to metatable */
		lua_pushvalue(L, 1);  /* push library */
		lua_setfield(L, -2, "__index");  /* metatable.__index = library */
		lua_pop(L, 1);  /* pop metatable */
	}
	lua_pop(L, 1);  /* pop memory */
}


LUAMEMMOD_API int luaopen_memory (lua_State *L) {
	luaL_newlib(L, lib);
	luamem_newalloc(L, 0);
	setupmetatable(L);
	luamem_newref(L);
	setupmetatable(L);
	return 1;
}

/*
* NOTE: most of the code below is copied from the source of Lua 5.3.1 by
*       R. Ierusalimschy, L. H. de Figueiredo, W. Celes - Lua.org, PUC-Rio.
*
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
*/



/* macro to 'unsign' a character */
#define uchar(c)	((unsigned char)(c))


/* translate a relative string position: negative means back from end */
static lua_Integer posrelat (lua_Integer pos, size_t len) {
	if (pos >= 0) return pos;
	else if (0u - (size_t)pos > len) return 0;
	else return (lua_Integer)len + pos + 1;
}

static int str2byte (lua_State *L, const char *s, size_t l) {
	lua_Integer posi = posrelat(luaL_optinteger(L, 2, 1), l);
	lua_Integer pose = posrelat(luaL_optinteger(L, 3, posi), l);
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

static void code2char (lua_State *L, int idx, char *p, lua_Integer n) {
	int i;
	for (i=0; i<n; ++i, ++idx) {
		lua_Integer c = luaL_checkinteger(L, idx);
		luaL_argcheck(L, uchar(c) == c, idx, "value out of range");
		p[i] = uchar(c);
	}
}

static const char *lmemfind (const char *s1, size_t l1,
                             const char *s2, size_t l2) {
	if (l2 == 0) return s1;  /* empty strings are everywhere */
	else if (l2 > l1) return NULL;  /* avoids a negative 'l1' */
	else {
		const char *init;  /* to search for a '*s2' inside 's1' */
		l2--;  /* 1st char will be checked by 'memchr' */
		l1 = l1-l2;  /* 's2' cannot be found after that */
		while (l1 > 0 && (init = (const char *)memchr(s1, *s2, l1)) != NULL) {
			init++;   /* 1st char is already checked */
			if (memcmp(init, s2+1, l2) == 0)
				return init-1;
			else {  /* correct 'l1' and 's1' to try again */
				l1 -= init-s1;
				s1 = init;
			}
		}
		return NULL;  /* not found */
	}
}

/*
** {======================================================
** STRING FORMAT
** =======================================================
*/

#if !defined(lua_number2strx)	/* { */

/*
** Hexadecimal floating-point formatter
*/

#include <math.h>

#define SIZELENMOD	(sizeof(LUA_NUMBER_FRMLEN)/sizeof(char))


/*
** Number of bits that goes into the first digit. It can be any value
** between 1 and 4; the following definition tries to align the number
** to nibble boundaries by making what is left after that first digit a
** multiple of 4.
*/
#define L_NBFD		((l_mathlim(MANT_DIG) - 1)%4 + 1)


/*
** Add integer part of 'x' to buffer and return new 'x'
*/
static lua_Number adddigit (char *buff, int n, lua_Number x) {
	lua_Number dd = l_mathop(floor)(x);  /* get integer part from 'x' */
	int d = (int)dd;
	buff[n] = (d < 10 ? d + '0' : d - 10 + 'a');  /* add to buffer */
	return x - dd;  /* return what is left */
}


static int num2straux (char *buff, int sz, lua_Number x) {
	/* if 'inf' or 'NaN', format it like '%g' */
	if (x != x || x == (lua_Number)HUGE_VAL || x == -(lua_Number)HUGE_VAL)
		return l_sprintf(buff, sz, LUA_NUMBER_FMT, (LUAI_UACNUMBER)x);
	else if (x == 0) {  /* can be -0... */
		/* create "0" or "-0" followed by exponent */
		return l_sprintf(buff, sz, LUA_NUMBER_FMT "x0p+0", (LUAI_UACNUMBER)x);
	}
	else {
		int e;
		lua_Number m = l_mathop(frexp)(x, &e);  /* 'x' fraction and exponent */
		int n = 0;  /* character count */
		if (m < 0) {  /* is number negative? */
			buff[n++] = '-';  /* add signal */
			m = -m;  /* make it positive */
		}
		buff[n++] = '0'; buff[n++] = 'x';  /* add "0x" */
		m = adddigit(buff, n++, m * (1 << L_NBFD));  /* add first digit */
		e -= L_NBFD;  /* this digit goes before the radix point */
		if (m > 0) {  /* more digits? */
			buff[n++] = lua_getlocaledecpoint();  /* add radix point */
			do {  /* add as many digits as needed */
				m = adddigit(buff, n++, m * 16);
			} while (m > 0);
		}
		n += l_sprintf(buff + n, sz - n, "p%+d", e);  /* add exponent */
		lua_assert(n < sz);
		return n;
	}
}


static int lua_number2strx (lua_State *L, char *buff, int sz,
                            const char *fmt, lua_Number x) {
	int n = num2straux(buff, sz, x);
	if (fmt[SIZELENMOD] == 'A') {
		int i;
		for (i = 0; i < n; i++)
			buff[i] = toupper(uchar(buff[i]));
	}
	else if (fmt[SIZELENMOD] != 'a')
		luaL_error(L, "modifiers for format '%%a'/'%%A' not implemented");
	return n;
}

#endif				/* } */


#if !defined(LUA_USE_C89)

#define lmem_sprintf(s,sz,f,i)	l_sprintf(s,sz,f,i)
#define lmem_number2strx(L,b,sz,f,x)	lua_number2strx(L,b,sz,f,x)

#else

/*
** Maximum size of each formatted item. This maximum size is produced
** by format('%.99f', -maxfloat), and is equal to 99 + 3 ('-', '.',
** and '\0') + number of decimal digits to represent maxfloat (which
** is maximum exponent + 1). (99+3+1 then rounded to 120 for "extra
** expenses", such as locale-dependent stuff)
*/
#define MAX_ITEM        (120 + l_mathlim(MAX_10_EXP))

static int lmem_sprintf(char *s, size_t sz, const char *fmt, ...) {
	va_list argp;
	int n;
	char tmp[MAX_ITEM], *dst = sz < MAX_ITEM ? tmp : s;
	va_start(argp, fmt);
	n = sprintf(dst, fmt, va_arg(argp, void *));
	va_end(argp);
	if (dst == tmp) memcpy(s, tmp, sz < n ? sz : n);
	return n;
}

static int lmem_number2strx (lua_State *L, char *buff, int sz,
                            const char *fmt, lua_Number x) {
	char tmp[MAX_ITEM], *dst = sz < MAX_ITEM ? tmp : s;
	int n = lua_number2strx(L, *buff, sz, fmt, x);
	if (dst == tmp) memcpy(s, tmp, sz < n ? sz : n);
	return n;
}

#endif


#define L_ESC		'%'

/* valid flags in a format specification */
#define FLAGS	"-+ #0"

/*
** maximum size of each format specification (such as "%-099.99d")
*/
#define MAX_FORMAT	32


static int packnum2strx (lua_State *L, char **b, size_t *i, size_t lb,
                         const char *fmt, lua_Number x) {
	if (*i < lb) {
		size_t sz = lb-*i;
		int n = lmem_number2strx(L, *b, sz, fmt, x);
		if (n <= sz) {
			*i += n;
			*b += n;
			return 1;
		}
	}
	return 0;
}


static int packfmt (char **b, size_t *i, size_t lb, const char *fmt, ...) {
	if (*i < lb) {
		size_t n, sz = lb-*i;
		va_list argp;
		va_start(argp, fmt);
		n = lmem_sprintf(*b, sz, fmt, va_arg(argp, void *));
		va_end(argp);
		if (n <= sz) {
			*i += n;
			*b += n;
			return 1;
		}
	}
	return 0;
}


static int packchar (char **b, size_t *i, size_t lb, const char c) {
	if (*i < lb) {
		(void)*i++;
		*(*b++) = c;
		return 1;
	}
	return 0;
}


static char *getbytes (char **b, size_t *i, size_t lb, size_t sz) {
	size_t newtotal = *i+sz;
	if (newtotal < lb) {
		char *res = *b;
		*b += sz;
		*i = newtotal;
		return res;
	}
	return NULL;
}


static int packstream (char **b, size_t *i, size_t lb,
                       const char *s, size_t sl) {
	if (sl > 0) {  /* avoid 'memcpy' when 's' can be NULL */
		char *d = getbytes(b, i, lb, sl);
		if (d == NULL) return 0;
		memcpy(d, s, sl * sizeof(char));
	}
	return 1;
}


static int packquoted (char **b, size_t *i, size_t lb,
                      const char *s, size_t len) {
	if (!packchar(b, i, lb, '"')) return 0;
	while (len--) {
		int res;
		if (*s == '"' || *s == '\\' || *s == '\n')
			if (res = packchar(b, i, lb, '\\')) res = packchar(b, i, lb, *s);
		else if (iscntrl(uchar(*s)))
			if (!isdigit(uchar(*(s+1))))
				res = packfmt(b, i, lb, "\\%d", (int)uchar(*s));
			else
				res = packfmt(b, i, lb, "\\%03d", (int)uchar(*s));
		else
			res = packchar(b, i, lb, *s);
		if (!res) return 0;
		s++;
	}
	return packchar(b, i, lb, '"');
}


/*
** Ensures the 'buff' string uses a dot as the radix character.
*/
static void checkdp (char *buff, int nb) {
	if (memchr(buff, '.', nb) == NULL) {  /* no dot? */
		char point = lua_getlocaledecpoint();  /* try locale point */
		char *ppoint = (char *)memchr(buff, point, nb);
		if (ppoint) *ppoint = '.';  /* change it to a dot */
	}
}


static int packliteral (lua_State *L, char **b, size_t *i, size_t lb, int arg) {
	switch (lua_type(L, arg)) {
		case LUA_TSTRING: {
			size_t len;
			const char *s = lua_tolstring(L, arg, &len);
			return packquoted(b, i, lb, s, len);
		}
		case LUA_TNUMBER: {
			if (!lua_isinteger(L, arg)) {  /* float? */
				lua_Number n = lua_tonumber(L, arg);  /* write as hexa ('%a') */
				size_t offset = *i;
				char *buffer = *b+offset;
				int res = packnum2strx(L, b, i, lb, "%" LUA_NUMBER_FRMLEN "a", n);
				checkdp(buffer, *i-offset);  /* ensure it uses a dot */
				return res;
			}
			else {  /* integers */
				lua_Integer n = lua_tointeger(L, arg);
				const char *format = (n == LUA_MININTEGER)  /* corner case? */
				                   ? "0x%" LUA_INTEGER_FRMLEN "x"  /* use hexa */
				                   : LUA_INTEGER_FMT;  /* else use default format */
				return packfmt(b, i, lb, format, (LUAI_UACINT)n);
			}
		}
		case LUA_TNIL: case LUA_TBOOLEAN: {
			size_t len;
			const char *s = luaL_tolstring(L, arg, &len);
			int res = packstream(b, i, lb, s, len);
			lua_pop(L, 1);  /* remove result from 'luaL_tolstring' */
			return res;
		}
		case LUA_TUSERDATA: {
			size_t len;
			int type;
			const char *s = luamem_tomemoryx(L, arg, &len, NULL, &type);
			if (type != LUAMEM_TNONE) return packquoted(b, i, lb, s, len);
		}
	}
	return luaL_argerror(L, arg, "value has no literal form");
}

static int packfailed (lua_State *L, size_t i, size_t arg) {
	lua_pushboolean(L, 0);
	lua_replace(L, arg-2);
	lua_pushinteger(L, i+1);
	lua_replace(L, arg-1);
	return 3+lua_gettop(L)-arg;
}


static const char *scanformat (lua_State *L, const char *strfrmt, char *form) {
	const char *p = strfrmt;
	while (*p != '\0' && strchr(FLAGS, *p) != NULL) p++;  /* skip flags */
	if ((size_t)(p - strfrmt) >= sizeof(FLAGS)/sizeof(char))
		luaL_error(L, "invalid format (repeated flags)");
	if (isdigit(uchar(*p))) p++;  /* skip width */
	if (isdigit(uchar(*p))) p++;  /* (2 digits at most) */
	if (*p == '.') {
		p++;
		if (isdigit(uchar(*p))) p++;  /* skip precision */
		if (isdigit(uchar(*p))) p++;  /* (2 digits at most) */
	}
	if (isdigit(uchar(*p)))
		luaL_error(L, "invalid format (width or precision too long)");
	*(form++) = '%';
	memcpy(form, strfrmt, ((p - strfrmt) + 1) * sizeof(char));
	form += (p - strfrmt) + 1;
	*form = '\0';
	return p;
}


/*
** add length modifier into formats
*/
static void addlenmod (char *form, const char *lenmod) {
	size_t l = strlen(form);
	size_t lm = strlen(lenmod);
	char spec = form[l - 1];
	strcpy(form + l - 1, lenmod);
	form[l + lm - 1] = spec;
	form[l + lm] = '\0';
}


static int mem_format (lua_State *L) {
	int top = lua_gettop(L);
	int arg = 1;
	size_t i, lb, sfl;
	char *mem = luamem_checkmemory(L, arg, &lb);
	const char *strfrmt = luaL_checklstring(L, ++arg, &sfl);
	const char *strfrmt_end = strfrmt+sfl;
	lua_Integer pos = posrelat(luaL_checkinteger(L, ++arg), lb) - 1;
	luaL_argcheck(L, 0 <= pos && pos <= (lua_Integer)lb-1, arg,
		"index out of bounds");
	i = (size_t)pos;
	mem += i;
	while (strfrmt < strfrmt_end) {
		int res;
		if (*strfrmt != L_ESC)
			res = packchar(&mem, &i, lb, *strfrmt++);
		else if (*++strfrmt == L_ESC)  /* %% */
			res = packchar(&mem, &i, lb, *strfrmt++);
		else { /* format item */
			char form[MAX_FORMAT];  /* to store the format ('%...') */
			if (++arg > top) luaL_argerror(L, arg, "no value");
			strfrmt = scanformat(L, strfrmt, form);
			switch (*strfrmt++) {
				case 'c': {
					res = packfmt(&mem, &i, lb, form, (int)luaL_checkinteger(L, arg));
					break;
				}
				case 'd': case 'i':
				case 'o': case 'u': case 'x': case 'X': {
					lua_Integer n = luaL_checkinteger(L, arg);
					addlenmod(form, LUA_INTEGER_FRMLEN);
					res = packfmt(&mem, &i, lb, form, (LUAI_UACINT)n);
					break;
				}
				case 'a': case 'A': {
					addlenmod(form, LUA_NUMBER_FRMLEN);
					res = packnum2strx(L, &mem, &i, lb, form, luaL_checknumber(L, arg));
					break;
				}
				case 'e': case 'E': case 'f':
				case 'g': case 'G': {
					lua_Number n = luaL_checknumber(L, arg);
					addlenmod(form, LUA_NUMBER_FRMLEN);
					res = packfmt(&mem, &i, lb, form, (LUAI_UACNUMBER)n);
					break;
				}
				case 'q': {

printf("packliteral(L, mem, %ld, %ld, arg)\n", i, lb);

					res = packliteral(L, &mem, &i, lb, arg);

printf("           i=%ld lb=%ld res=%d\n", i, lb, res);

					break;
				}
				case 's': {
					size_t l;
					const char *s = luaL_tolstring(L, arg, &l);
					if (form[2] == '\0')  /* no modifiers? */
						res = packstream(&mem, &i, lb, s, l);  /* keep entire string */
					else {
						luaL_argcheck(L, l == strlen(s), arg, "string contains zeros");
						if (!strchr(form, '.') && l >= 100) {
							/* no precision and string is too long to be formatted */
							res = packstream(&mem, &i, lb, s, l);  /* keep entire string */
						} else {
							/* format the string into 'buff' */
							res = packfmt(&mem, &i, lb, form, s);
						}
					}
					lua_pop(L, 1);  /* remove result from 'luaL_tolstring' */
					break;
				}
				default: {  /* also treat cases 'pnLlh' */
					return luaL_error(L, "invalid option '%%%c' to 'format'",
					                     *(strfrmt - 1));
				}
			}
		}
		if (!res) return packfailed(L, i, arg);
	}
	lua_pushboolean(L, 1);
	lua_pushinteger(L, i+1);
	return 2;
}

/* }====================================================== */


/*
** {======================================================
** PACK/UNPACK
** =======================================================
*/

/* value used for padding */
#if !defined(LUA_PACKPADBYTE)
#define LUA_PACKPADBYTE		0x00
#endif

/* maximum size for the binary representation of an integer */
#define MAXINTSIZE	16

/* number of bits in a character */
#define NB	CHAR_BIT

/* mask for one character (NB 1's) */
#define MC	((1 << NB) - 1)

/* size of a lua_Integer */
#define SZINT	((int)sizeof(lua_Integer))


/* dummy union to get native endianness */
static const union {
	int dummy;
	char little;  /* true iff machine is little endian */
} nativeendian = {1};


/* dummy structure to get native alignment requirements */
struct cD {
	char c;
	union { double d; void *p; lua_Integer i; lua_Number n; } u;
};

#define MAXALIGN	(offsetof(struct cD, u))


/*
** Union for serializing floats
*/
typedef union Ftypes {
	float f;
	double d;
	lua_Number n;
	char buff[5 * sizeof(lua_Number)];  /* enough for any float type */
} Ftypes;


/*
** information to pack/unpack stuff
*/
typedef struct Header {
	lua_State *L;
	int islittle;
	int maxalign;
} Header;


/*
** options for pack/unpack
*/
typedef enum KOption {
	Kint,		/* signed integers */
	Kuint,	/* unsigned integers */
	Kfloat,	/* floating-point numbers */
	Kchar,	/* fixed-length strings */
	Kstring,	/* strings with prefixed length */
	Kzstr,	/* zero-terminated strings */
	Kpadding,	/* padding */
	Kpaddalign,	/* padding for alignment */
	Knop		/* no-op (configuration or spaces) */
} KOption;


/*
** Read an integer numeral from string 'fmt' or return 'df' if
** there is no numeral
*/
static int digit (int c) { return '0' <= c && c <= '9'; }

static int getnum (const char **fmt, int df) {
	if (!digit(**fmt))  /* no number? */
		return df;  /* return default value */
	else {
		int a = 0;
		do {
			a = a*10 + (*((*fmt)++) - '0');
		} while (digit(**fmt) && a <= ((int)LUAMEM_MAXALLOC - 9)/10);
		return a;
	}
}


/*
** Read an integer numeral and raises an error if it is larger
** than the maximum size for integers.
*/
static int getnumlimit (Header *h, const char **fmt, int df) {
	int sz = getnum(fmt, df);
	if (sz > MAXINTSIZE || sz <= 0)
		luaL_error(h->L, "integral size (%d) out of limits [1,%d]",
		                 sz, MAXINTSIZE);
	return sz;
}


/*
** Initialize Header
*/
static void initheader (lua_State *L, Header *h) {
	h->L = L;
	h->islittle = nativeendian.little;
	h->maxalign = 1;
}


/*
** Read and classify next option. 'size' is filled with option's size.
*/
static KOption getoption (Header *h, const char **fmt, int *size) {
	int opt = *((*fmt)++);
	*size = 0;  /* default */
	switch (opt) {
		case 'b': *size = sizeof(char); return Kint;
		case 'B': *size = sizeof(char); return Kuint;
		case 'h': *size = sizeof(short); return Kint;
		case 'H': *size = sizeof(short); return Kuint;
		case 'l': *size = sizeof(long); return Kint;
		case 'L': *size = sizeof(long); return Kuint;
		case 'j': *size = sizeof(lua_Integer); return Kint;
		case 'J': *size = sizeof(lua_Integer); return Kuint;
		case 'T': *size = sizeof(size_t); return Kuint;
		case 'f': *size = sizeof(float); return Kfloat;
		case 'd': *size = sizeof(double); return Kfloat;
		case 'n': *size = sizeof(lua_Number); return Kfloat;
		case 'i': *size = getnumlimit(h, fmt, sizeof(int)); return Kint;
		case 'I': *size = getnumlimit(h, fmt, sizeof(int)); return Kuint;
		case 's': *size = getnumlimit(h, fmt, sizeof(size_t)); return Kstring;
		case 'c':
			*size = getnum(fmt, -1);
			if (*size == -1)
				luaL_error(h->L, "missing size for format option 'c'");
			return Kchar;
		case 'z': return Kzstr;
		case 'x': *size = 1; return Kpadding;
		case 'X': return Kpaddalign;
		case ' ': break;
		case '<': h->islittle = 1; break;
		case '>': h->islittle = 0; break;
		case '=': h->islittle = nativeendian.little; break;
		case '!': h->maxalign = getnumlimit(h, fmt, MAXALIGN); break;
		default: luaL_error(h->L, "invalid format option '%c'", opt);
	}
	return Knop;
}


/*
** Read, classify, and fill other details about the next option.
** 'psize' is filled with option's size, 'notoalign' with its
** alignment requirements.
** Local variable 'size' gets the size to be aligned. (Kpadal option
** always gets its full alignment, other options are limited by 
** the maximum alignment ('maxalign'). Kchar option needs no alignment
** despite its size.
*/
static KOption getdetails (Header *h, size_t totalsize,
                           const char **fmt, int *psize, int *ntoalign) {
	KOption opt = getoption(h, fmt, psize);
	int align = *psize;  /* usually, alignment follows size */
	if (opt == Kpaddalign) {  /* 'X' gets alignment from following option */
		if (**fmt == '\0' || getoption(h, fmt, &align) == Kchar || align == 0)
			luaL_argerror(h->L, 1, "invalid next option for option 'X'");
	}
	if (align <= 1 || opt == Kchar)  /* need no alignment? */
		*ntoalign = 0;
	else {
		if (align > h->maxalign)  /* enforce maximum alignment */
			align = h->maxalign;
		if ((align & (align - 1)) != 0)  /* is 'align' not a power of 2? */
			luaL_argerror(h->L, 1, "format asks for alignment not power of 2");
		*ntoalign = (align - (int)(totalsize & (align - 1))) & (align - 1);
	}
	return opt;
}


/*
** Pack integer 'n' with 'size' bytes and 'islittle' endianness.
** The final 'if' handles the case when 'size' is larger than
** the size of a Lua integer, correcting the extra sign-extension
** bytes if necessary (by default they would be zeros).
*/
static int packint (char **b, size_t *pos, size_t lb,
                    lua_Unsigned n, int islittle, int size, int neg) {
	char *buff = getbytes(b, pos, lb, size);
	if (buff) {
		int i;
		buff[islittle ? 0 : size - 1] = (char)(n & MC);  /* first byte */
		for (i = 1; i < size; i++) {
			n >>= NB;
			buff[islittle ? i : size - 1 - i] = (char)(n & MC);
		}
		if (neg && size > SZINT) {  /* negative number need sign extension? */
			for (i = SZINT; i < size; i++)  /* correct extra bytes */
				buff[islittle ? i : size - 1 - i] = (char)MC;
		}
		return 1;
	}
	return 0;
}


/*
** Copy 'size' bytes from 'src' to 'dest', correcting endianness if
** given 'islittle' is different from native endianness.
*/
static void copywithendian (volatile char *dest, volatile const char *src,
                            int size, int islittle) {
	if (islittle == nativeendian.little) {
		while (size-- != 0)
			*(dest++) = *(src++);
	}
	else {
		dest += size - 1;
		while (size-- != 0)
			*(dest--) = *(src++);
	}
}

static int mem_pack (lua_State *L) {
	Header h;
	size_t i, lb;
	char *mem = luamem_checkmemory(L, 1, &lb);
	const char *fmt = luaL_checkstring(L, 2);  /* format string */
	lua_Integer pos = posrelat(luaL_checkinteger(L, 3), lb) - 1;
	int arg = 3;  /* current argument to pack */
	luaL_argcheck(L, 0 <= pos && pos <= (lua_Integer)lb-1, 3,
		"index out of bounds");
	initheader(L, &h);
	i = (size_t)pos;
	mem += i;
	while (*fmt != '\0') {
		int size, ntoalign;
		KOption opt = getdetails(&h, i, &fmt, &size, &ntoalign);
		arg++;
		if (!getbytes(&mem, &i, lb, ntoalign))  /* skip alignment */
			return packfailed(L, i, arg);
		switch (opt) {
			case Kint: {  /* signed integers */
				lua_Integer n = luaL_checkinteger(L, arg);
				if (size < SZINT) {  /* need overflow check? */
					lua_Integer lim = (lua_Integer)1 << ((size * NB) - 1);
					luaL_argcheck(L, -lim <= n && n < lim, arg, "integer overflow");
				}
				if (!packint(&mem, &i, lb, (lua_Unsigned)n, h.islittle, size, (n < 0)))
					return packfailed(L, i, arg);
				break;
			}
			case Kuint: {  /* unsigned integers */
				lua_Integer n = luaL_checkinteger(L, arg);
				if (size < SZINT)  /* need overflow check? */
					luaL_argcheck(L, (lua_Unsigned)n < ((lua_Unsigned)1 << (size * NB)),
					                 arg, "unsigned overflow");
				if (!packint(&mem, &i, lb, (lua_Unsigned)n, h.islittle, size, 0))
					return packfailed(L, i, arg);
				break;
			}
			case Kfloat: {  /* floating-point options */
				volatile Ftypes u;
				lua_Number n;
				char *data = getbytes(&mem, &i, lb, size);
				if (!data) return packfailed(L, i, arg);
				n = luaL_checknumber(L, arg);  /* get argument */
				if (size == sizeof(u.f)) u.f = (float)n;  /* copy it into 'u' */
				else if (size == sizeof(u.d)) u.d = (double)n;
				else u.n = n;
				/* move 'u' to final result, correcting endianness if needed */
				copywithendian(data, u.buff, size, h.islittle);
				break;
			}
			case Kchar: {  /* fixed-size string */
				size_t len;
				const char *s = luamem_checkstring(L, arg, &len);
				luaL_argcheck(L, len == (size_t)size, arg, "wrong length");
				if (!packstream(&mem, &i, lb, s, size))
					return packfailed(L, i, arg);
				break;
			}
			case Kstring: {  /* strings with length count */
				size_t len;
				const char *s = luamem_checkstring(L, arg, &len);
				luaL_argcheck(L, size >= (int)sizeof(size_t) ||
				                 len < ((size_t)1 << (size * NB)),
				                 arg, "string length does not fit in given size");
				if (!packint(&mem, &i, lb, (lua_Unsigned)len, h.islittle, size, 0) ||  /* pack length */
				    !packstream(&mem, &i, lb, s, len))
					return packfailed(L, i, arg);
				break;
			}
			case Kzstr: {  /* zero-terminated string */
				size_t len;
				const char *s = luamem_checkstring(L, arg, &len);
				luaL_argcheck(L, strlen(s) == len, arg, "string contains zeros");
				if (!packstream(&mem, &i, lb, s, len) || !packchar(&mem, &i, lb, '\0'))
					return packfailed(L, i, arg);
				break;
			}
			case Kpadding: {
				if (!getbytes(&mem, &i, lb, 1))
					return packfailed(L, i, arg);
				/* go through */
			}
			case Kpaddalign: case Knop:
				arg--;  /* undo increment */
				break;
		}
	}
	lua_pushboolean(L, 1);
	lua_pushinteger(L, i+1);
	return 2;
}


/*
** Unpack an integer with 'size' bytes and 'islittle' endianness.
** If size is smaller than the size of a Lua integer and integer
** is signed, must do sign extension (propagating the sign to the
** higher bits); if size is larger than the size of a Lua integer,
** it must check the unread bytes to see whether they do not cause an
** overflow.
*/
static lua_Integer unpackint (lua_State *L, const char *str,
                              int islittle, int size, int issigned) {
	lua_Unsigned res = 0;
	int i;
	int limit = (size  <= SZINT) ? size : SZINT;
	for (i = limit - 1; i >= 0; i--) {
		res <<= NB;
		res |= (lua_Unsigned)uchar(str[islittle ? i : size - 1 - i]);
	}
	if (size < SZINT) {  /* real size smaller than lua_Integer? */
		if (issigned) {  /* needs sign extension? */
			lua_Unsigned mask = (lua_Unsigned)1 << (size*NB - 1);
			res = ((res ^ mask) - mask);  /* do sign extension */
		}
	}
	else if (size > SZINT) {  /* must check unread bytes */
		int mask = (!issigned || (lua_Integer)res >= 0) ? 0 : MC;
		for (i = limit; i < size; i++) {
			if (uchar(str[islittle ? i : size - 1 - i]) != mask)
				luaL_error(L, "%d-byte integer does not fit into Lua Integer", size);
		}
	}
	return (lua_Integer)res;
}


static int mem_unpack (lua_State *L) {
	Header h;
	size_t ld;
	const char *data = luamem_checkmemory(L, 1, &ld);
	const char *fmt = luaL_checkstring(L, 2);
	size_t pos = (size_t)posrelat(luaL_optinteger(L, 3, 1), ld) - 1;
	int n = 0;  /* number of results */
	luaL_argcheck(L, pos <= ld, 3, "initial position out of bounds");
	initheader(L, &h);
	while (*fmt != '\0') {
		int size, ntoalign;
		KOption opt = getdetails(&h, pos, &fmt, &size, &ntoalign);
		if ((size_t)ntoalign + size > ~pos || pos + ntoalign + size > ld)
			luaL_argerror(L, 1, "data too short");
		pos += ntoalign;  /* skip alignment */
		/* stack space for item + next position */
		luaL_checkstack(L, 1, "too many results");
		n++;
		switch (opt) {
			case Kint:
			case Kuint: {
				lua_Integer res = unpackint(L, data + pos, h.islittle, size,
				                               (opt == Kint));
				lua_pushinteger(L, res);
				break;
			}
			case Kfloat: {
				volatile Ftypes u;
				lua_Number num;
				copywithendian(u.buff, data + pos, size, h.islittle);
				if (size == sizeof(u.f)) num = (lua_Number)u.f;
				else if (size == sizeof(u.d)) num = (lua_Number)u.d;
				else num = u.n;
				lua_pushnumber(L, num);
				break;
			}
			case Kchar: {
				lua_pushlstring(L, data + pos, size);
				break;
			}
			case Kstring: {
				size_t len = (size_t)unpackint(L, data + pos, h.islittle, size, 0);
				luaL_argcheck(L, pos + len + size <= ld, 2, "data string too short");
				lua_pushlstring(L, data + pos + size, len);
				pos += len;  /* skip string */
				break;
			}
			case Kzstr: {
				size_t len = (int)strlen(data + pos);
				lua_pushlstring(L, data + pos, len);
				pos += len + 1;  /* skip string plus final '\0' */
				break;
			}
			case Kpaddalign: case Kpadding: case Knop:
				n--;  /* undo increment */
				break;
		}
		pos += size;
	}
	lua_pushinteger(L, pos + 1);  /* next position */
	return n + 1;
}

/* }====================================================== */
