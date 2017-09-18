/*
** $Id$
** Stream support for the Lua language
** See Copyright Notice in lstraux.h
*/

#define lbuflib_c

#include "lstraux.h"
#include "lstrops.h"

#include <string.h>



static int buf_create (lua_State *L) {
	char *p;
	size_t lb;
	const char *s = NULL;
	if (lua_type(L, 1) == LUA_TNUMBER) {
		lua_Integer sz = luaL_checkinteger(L, 1);
		luaL_argcheck(L, 0 <= sz && sz < (lua_Integer)LUABUF_MAXSIZE, 1,
		                                                 "invalid size");
		lb = (size_t)sz;
	} else {
		lua_Integer posi, pose;
		s = luabuf_checkstream(L, 1, &lb);
		posi = luastreamI_posrelat(luaL_optinteger(L, 2, 1), lb);
		pose = luastreamI_posrelat(luaL_optinteger(L, 3, -1), lb);
		if (posi < 1) posi = 1;
		if (pose > (lua_Integer)lb) pose = lb;
		if (posi > pose) {
			lb = 0;
			s = NULL;
		} else {
			lb = (int)(pose - posi + 1);
			if (posi + lb <= pose)  /* arithmetic overflow? */
				return luaL_error(L, "string slice too long");
			s += posi-1;
		}
	}
	p = luabuf_newbuffer(L, lb);
	if (s) memcpy(p, s, lb * sizeof(char));
	return 1;
}

static int buf_len (lua_State *L) {
	size_t lb;
	luabuf_checkbuffer(L, 1, &lb);
	lua_pushinteger(L, (lua_Integer)lb);
	return 1;
}

static int buf_tostring (lua_State *L) {
	size_t lb;
	const char *s = luabuf_checkbuffer(L, 1, &lb);
	if (lb>0) lua_pushlstring(L, s, lb);
	else lua_pushliteral(L, "");
	return 1;
}

static int buf_get (lua_State *L) {
	size_t lb;
	const char *s = luabuf_checkbuffer(L, 1, &lb);
	return luastreamI_str2byte(L, s, lb);
}

static int buf_set (lua_State *L) {
	size_t lb;
	int n = lua_gettop(L)-2;  /* number of bytes */
	char *p = luabuf_checkbuffer(L, 1, &lb);
	lua_Integer i = luastreamI_posrelat(luaL_checkinteger(L, 2), lb);
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)lb, 2, "index out of bounds");
	lb = 1+lb-i;
	luastreamI_code2char(L, 3, p+i-1, n<lb ? n : lb);
	return 0;
}

static int buf_fill (lua_State *L) {
	size_t lb, sl;
	char *p = luabuf_checkbuffer(L, 1, &lb);
	lua_Integer i = luastreamI_posrelat(luaL_optinteger(L, 3, 1), lb);
	lua_Integer j = luastreamI_posrelat(luaL_optinteger(L, 4, -1), lb);
	char c;
	const char *s = NULL;
	lua_Integer os;
	if (lua_type(L, 2) == LUA_TNUMBER) {
		s = &c;
		sl = 1;
		os = 1;
		luastreamI_code2char(L, 2, &c, 1);
	} else {
		s = luabuf_checkstream(L, 2, &sl);
		os = luastreamI_posrelat(luaL_optinteger(L, 5, 1), sl);
	}
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)lb, 3, "index out of bounds");
	luaL_argcheck(L, 1 <= j && j <= (lua_Integer)lb, 4, "index out of bounds");
	if (os < 1) os = 1;
	if (i <= j && os <= (lua_Integer)sl) {
		int n = (int)(j - i + 1);
		if (i + n <= j)  /* arithmetic overflow? */
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
		} while (digit(**fmt) && a <= ((int)LUABUF_MAXSIZE - 9)/10);
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
		*b += newtotal;
		*i = newtotal;
		return res;
	}
	return NULL;
}

static int packfailed (lua_State *L, size_t i, size_t arg) {
	lua_pushboolean(L, 0);
	lua_pushinteger(L, i+1);
	lua_pushinteger(L, arg-3);
	return 3;
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
static int packint (char **b, size_t *i, size_t lb,
                    lua_Unsigned n, int islittle, int size, int neg) {
	char *buff = getbytes(b, i, lb, size);
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

static int buf_pack (lua_State *L) {
	Header h;
	size_t lb;
	char *buff = luabuf_checkbuffer(L, 1, &lb);
	size_t i = (size_t)luastreamI_posrelat(luaL_checkinteger(L, 2), lb) - 1;
	const char *fmt = luaL_checkstring(L, 3);  /* format string */
	int arg = 3;  /* current argument to pack */
	luaL_argcheck(L, 1 <= i && i <= (lua_Integer)lb, 2, "index out of bounds");
	initheader(L, &h);
	while (*fmt != '\0') {
		int size, ntoalign;
		KOption opt = getdetails(&h, i, &fmt, &size, &ntoalign);
		arg++;
		if (!getbytes(&buff, &i, lb, ntoalign))  /* skip alignment */
			return packfailed(L, i, arg);
		switch (opt) {
			case Kint: {  /* signed integers */
				lua_Integer n = luaL_checkinteger(L, arg);
				if (size < SZINT) {  /* need overflow check? */
					lua_Integer lim = (lua_Integer)1 << ((size * NB) - 1);
					luaL_argcheck(L, -lim <= n && n < lim, arg, "integer overflow");
				}
				if (!packint(&buff, &i, lb, (lua_Unsigned)n, h.islittle, size, (n < 0)))
					return packfailed(L, i, arg);
				break;
			}
			case Kuint: {  /* unsigned integers */
				lua_Integer n = luaL_checkinteger(L, arg);
				if (size < SZINT)  /* need overflow check? */
					luaL_argcheck(L, (lua_Unsigned)n < ((lua_Unsigned)1 << (size * NB)),
					                 arg, "unsigned overflow");
				if (!packint(&buff, &i, lb, (lua_Unsigned)n, h.islittle, size, 0))
					return packfailed(L, i, arg);
				break;
			}
			case Kfloat: {  /* floating-point options */
				volatile Ftypes u;
				lua_Number n;
				char *data = getbytes(&buff, &i, lb, size);
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
				const char *s = luabuf_checkstream(L, arg, &len);
				luaL_argcheck(L, len == (size_t)size, arg, "wrong length");
				if (!packstream(&buff, &i, lb, s, size))
					return packfailed(L, i, arg);
				break;
			}
			case Kstring: {  /* strings with length count */
				size_t len;
				const char *s = luabuf_checkstream(L, arg, &len);
				luaL_argcheck(L, size >= (int)sizeof(size_t) ||
				                 len < ((size_t)1 << (size * NB)),
				                 arg, "string length does not fit in given size");
				if (!packint(&buff, &i, lb, (lua_Unsigned)len, h.islittle, size, 0) ||  /* pack length */
				    !packstream(&buff, &i, lb, s, len))
					return packfailed(L, i, arg);
				break;
			}
			case Kzstr: {  /* zero-terminated string */
				size_t len;
				const char *s = luabuf_checkstream(L, arg, &len);
				luaL_argcheck(L, strlen(s) == len, arg, "string contains zeros");
				if (!packstream(&buff, &i, lb, s, len) || !packchar(&buff, &i, lb, '\0'))
					return packfailed(L, i, arg);
				break;
			}
			case Kpadding: {
				if (!getbytes(&buff, &i, lb, 1))
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
	lua_pushinteger(L, arg-2);
	return 3;
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
		res |= (lua_Unsigned)(unsigned char)str[islittle ? i : size - 1 - i];
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
			if ((unsigned char)str[islittle ? i : size - 1 - i] != mask)
				luaL_error(L, "%d-byte integer does not fit into Lua Integer", size);
		}
	}
	return (lua_Integer)res;
}


static int buf_unpack (lua_State *L) {
	Header h;
	size_t ld;
	const char *data = luabuf_checkbuffer(L, 1, &ld);
	size_t pos = (size_t)luastreamI_posrelat(luaL_checkinteger(L, 2), ld) - 1;
	const char *fmt = luaL_checkstring(L, 3);
	int n = 0;  /* number of results */
	luaL_argcheck(L, pos <= ld, 2, "initial position out of bounds");
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



static const luaL_Reg buflib[] = {
	{"create", buf_create},
	{"fill", buf_fill},
	{"get", buf_get},
	{"len", buf_len},
	{"set", buf_set},
	{"pack", buf_pack},
	{"unpack", buf_unpack},
	{NULL, NULL}
};

static const luaL_Reg bufmeta[] = {
	{"__len", buf_len},
	{"__tostring", buf_tostring},
	{NULL, NULL}
};


static void createmetatable (lua_State *L) {
	if (!luaL_getmetatable(L, LUABUF_BUFFER)) {
		lua_pop(L, 1);  /* pop 'nil' */
		luaL_newmetatable(L, LUABUF_BUFFER);
	}
	luaL_setfuncs(L, bufmeta, 0);  /* add buffer methods to new metatable */
	lua_pop(L, 1);  /* pop new metatable */
}


LUABUFMOD_API int luaopen_buffer (lua_State *L) {
	luaL_newlib(L, buflib);
	createmetatable(L);
	return 1;
}
