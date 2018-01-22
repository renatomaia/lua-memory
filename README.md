Lua Memory
==========

The purpose of this project is to support manipulation of fixed-size memory areas in Lua.
These memory areas are much like Lua strings, but their contents can be modified in place and have an identity (selfness) independent from their contents.
The library provides the following functionalities:

- Support for writable memory areas.
- C API to manipulate strings or memory areas in a unified way.
- Alternative implementations of standard Lua libraries that manipulate memory areas just like strings.

TODO
----

- Make every memory provide `memory.*` functions as methods.
- Assure every memory always have a `\0` after its last byte.
- Write the manual
- Add support to create a memory using a pointer (potentially to a memory area external to Lua) using the C API.

```lua
int freeluamem (lua_State *L)
{
	void *p = luamem_toexternal(L, 1, NULL);
	if (p) free(p);
	return 0;
}

size_t sz = 16;
void *p = malloc(sz);
luamem_setexternal(L, p, sz, NULL); -- is persistent, so 'p' is accessible from Lua even if it leaves the stack.
luamem_setexternal(L, p, sz, freeluamem); -- is collectable, but 'p' is accessible from Lua.
luamem_setexternal(L, p, 0, NULL); -- is collectable also

typedef struct luamem_External {
	lua_CFunction callback;
	size_t size;
	/* private part */
	void *memory.
} luamem_External;

luamem_External *luamem_newexternal (lua_State *L, void *mem) {
	lua_
	luamem_External *lm =
		(luamem_External *)lua_newuserdata(L, sizeof(luamem_External));
	lm->callback = NULL;
	lm->size = 0;
	lm->memory = mem;
	return lm;
}
	if sz == 0 then mem = "\0" end
	#ifndef LUAMEMORY_NOCHECKNULLTERM
		assert(mem[sz] == '\0')
	#endif
	local refs = debug.getregistry().LuaMemoryExternalWeakRefs
	--assert(getmetatable(refs).__mode == "v")
	local key = lightuserdata(mem)
	local memory = refs[key]
	if memory == nil then
		memory = external{
			memory = mem,
			size = sz,
			gccallback = gc
		}
		refs[key] = memory
	else
		memory.size = sz
		memory.gccallback = gc
	end
	lua_pushvalue(memory) -- only value left pushed to the stack
}
int luamem_getexternal(lua_State *L, void *mem) {
	local reg = debug.getregistry().LuaMemoryPointerWeakRegistry
	assert(getmetatable(reg).__mode == "v")
	local found = reg[lightuserdata(mem)]
	if getmetatable(found) == LuaMemoryExternalMetatable then
		lua_pushvalue(found) -- only value left pushed to the stack
		return true
	end
	return false
}
void *luamem_toexternal(lua_State *L, int idx, size_t *sz);
int luamem_isexternal(lua_State *L, int idx);

#define ldata_newref(L,p,s)	(luamem_setexternal(L, p, s, NULL), p)
#define ldata_unref(L,p)	luamem_setexternal(L, p, 0, NULL)
```

Documentation
-------------

- [Manual](doc/manual.md)
- [License](LICENSE)

History
-------

Version 1.0:
:	First release.
