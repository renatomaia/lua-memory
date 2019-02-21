#define lmemmod_c

#include "lmemlib.h"

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
		if (s) memcpy(p, s, len * sizeof(char));
		else memset(p, 0, len * sizeof(char));
	}
	return 1;
}

static int mem_resize (lua_State *L) {
	size_t len;
	luamem_Unref unref;
	char *mem = luamem_tomemoryx(L, 1, &len, &unref, NULL);
	size_t size = luamem_checklenarg(L, 2);
	luaL_argcheck(L, unref == luamem_free, 1, "resizable memory expected");
	if (len != size) {
		char *resized = (char *)luamem_realloc(L, mem, len, size);
		if (!resized) luaL_error(L, "out of memory");
		luamem_setref(L, 1, mem, len, NULL);  /* don't free `mem` again */
		if (len < size) memset(resized+len, 0, (size-len)*sizeof(char));
		luamem_setref(L, 1, resized, size, luamem_free);
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
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)len, 3, "index out of bounds");
	luaL_argcheck(L, 1 <= j && j <= (lua_Integer)len, 4, "index out of bounds");
	if (os < 1) os = 1;
	if (i <= j && os <= (lua_Integer)sl) {
		size_t n = (size_t)(j-i+1);
		if (i+(lua_Integer)n <= j)  /* arithmetic overflow? */
			return luaL_error(L, "string slice too long");
		--os;
		s += os;
		sl -= os;
		do {
			size_t sz = n < sl ? n : sl;
			memmove(p+i-1, s, sz * sizeof(char));
			i += sz;
			n -= sz;
		} while (i <= j);
	}
	return 0;
}

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


static void setupmetatable (lua_State *L, const char *name) {
	luaL_newmetatable(L, name);
	luaL_setfuncs(L, meta, 0);  /* add metamethods to new metatable */
	lua_pushvalue(L, -2);  /* push library */
	lua_setfield(L, -2, "__index");  /* metatable.__index = library */
	lua_pop(L, 1);  /* pop new metatable */
}


LUAMEMMOD_API int luaopen_memory (lua_State *L) {
	luaL_newlib(L, lib);
	setupmetatable(L, LUAMEM_ALLOC);
	setupmetatable(L, LUAMEM_REF);
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


static char *getbytes (char **b, size_t *i, size_t lb, size_t sz) {
	size_t newtotal = *i+sz;
	if (newtotal<=lb) {
		char *res = *b;
		*b += sz;
		*i = newtotal;
		return res;
	}
	return NULL;
}

static int packfailed (lua_State *L, size_t i, size_t arg) {
	lua_pushboolean(L, 0);
	lua_replace(L, arg-2);
	lua_pushinteger(L, i+1);
	lua_replace(L, arg-1);
	return 3+lua_gettop(L)-arg;
}

static int packchar (char **b, size_t *i, size_t lb, const char c) {
	if (*i<lb) {
		(void)*i++;
		*(*b++) = c;
		return 1;
	}
	return 0;
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
