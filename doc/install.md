Index
=====

- [UNIX](#unix)
- [Windows](#windows)
- [LuaRocks](#luarocks)

Contents
========

UNIX
----

Read the [`Makefile`](Makefile) for further details,
but you can usually build and install the C library and the Lua module using the following commands:

```shell
make
make install
```

Windows
-------

Read the [`etc/Makefile.win`](etc/Makefile.win) for further details,
but you should be able to build and install the C library and Lua module using the `nmake` utility provided by Microsoft Visual C++.
For instance,
if your Lua is installed in `C:\Lua`,
you can type the following commands in a Microsoft Visual C++ console:

```shell
nmake /f etc/Makefile.win LUA_DIR=C:\Lua
nmake /f etc/Makefile.win install INSTALL_DIR=C:\Lua
```

LuaRocks
--------

Prior to install it as a rock,
you should first build and install its C library.
This way,
you can provide the C library to LuaRocks as an [external dependency](https://github.com/luarocks/luarocks/wiki/Platform-agnostic-external-dependencies) to be used for building rocks.
So,
first do the following commands to build and install only the C library:

```shell
make ALL=lib
make install_lib
```

This will install the C library in `/usr/local` by default.
Now you can install the Lua module as a rock with the following command:

```shell
luarocks make etc/luamemory-scm-1.rockspec
```
