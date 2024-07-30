#include <string.h>

#include "luamem.h"


static int mtst_assertcontents (lua_State *L) {
	size_t l, sz;
	const char *s = luaL_checklstring(L, 1, &l);
	char *mem = luamem_checkmemory(L, 2, &sz);

	luaL_argcheck(L, l == sz, 2, "incorrect size");
	luaL_argcheck(L, memcmp(mem, s, sz) == 0, 2, "incorrect contents");
#ifdef LUAMEM_NULLTERM
	luaL_argcheck(L, mem[sz] == '\0', 2, "no null termination byte");
#endif

	return 0;
}

static const luaL_Reg lib[] = {
	{"assertcontents", mtst_assertcontents},
	{NULL, NULL}
};


LUAMEMMOD_API int luaopen_memory_test (lua_State *L) {
	luaL_newlib(L, lib);
	return 1;
}
