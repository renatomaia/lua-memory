Install
=======

You can install both the [Lua module](manual.md#lua-module) and the [C library](manual.md#c-library) using [LuaRocks](https://www.luarocks.org/):

```shell
luarocks install memory
```

The C library is installed in paths given by the following commands:

```shell
MEMORY_ROCKDIR=$(luarocks show --rock-dir memory)
LUAMEM_LIBDIR=${MEMORY_ROCKDIR}/library
LUAMEM_INCDIR=${MEMORY_ROCKDIR}/include
```

Also, since [`rockspec_format =  3.1`](https://github.com/luarocks/luarocks/blob/main/docs/rockspec_format.md#package-metadata), LuaRocks provides variable `MEMORY_ROCKDIR` with this location for rockspecs that have LuaMemory's rock as a dependency.
See an example [here](https://github.com/renatomaia/coutil/blob/master/etc/coutil-scm-1.rockspec) of a rock that uses this to build a module linking to LuaMemory's C library.

Build from Source
=================

All the commands in the following sections are expected to be executed from the root of this Git repository.

LuaRocks
--------

You can use [LuaRocks](https://luarocks.org) to build and install it as a rock from the sources using the provided [rockspec](../etc/luamemory-scm-1.rockspec):

```shell
luarocks make etc/memory-scm-1.rockspec
```

CMake
-----

You also can build both the [Lua module](manual.md#lua-module) and the [C library](manual.md#c-library) with [CMake](https://cmake.org/):

```shell
cmake -B build -S . -DCMAKE_WINDOWS_EXPORT_ALL_SYMBOLS=ON
cmake --build build --config Release
cmake --install build
```

Expose The C API Dynamically
============================

You can make LuaMemory's C library available to dynamically loaded modules by loading it with `package.loadlib(libname, "*")`,
as documented [here](file:///home/renato/work/foss/lua/proj/coutil/bundle/lua-5.4.7/doc/manual.html#pdf-package.loadlib).

Moreover,
since LuaMemory's module is linked to its C library by default,
you can load the module instead of the C library to expose the symbols to other modules loaded dynamically:

```lua
local libpath = package.searchpath("memory", package.cpath)
if libpath then
  package.loadlib(libpath, "*")
end
```
