Lua Memory
==========

The purpose of this project is to support manipulation of memory areas in Lua.
These memory areas are much like Lua strings, but their contents can be modified in place and have an identity (selfness) independent from their contents.
The library provides the following components:

- [Module](doc/manual.md#lua-module) to manipulate memory areas in Lua.
- [C API](doc/manual.md#c-library) for manipulation memory areas in similar fashion to the [Lua C API](http://www.lua.org/manual/5.4/manual.html#4).

Documentation
-------------

- [License](LICENSE)
- [Install](doc/install.md)
- [Manual](doc/manual.md)
- [Demos](demo/)
  - [Create Fixed-Size Memory](demo/fixed.lua)
  - [Create Resizable Memory](demo/resizable.lua)
  - [Change Contents](demo/fill.lua)
  - [Inspect Contents](demo/inspect.lua)
  - [Compare Contents](demo/compare.lua)
  - [(Un)packing Data](demo/packing.lua)
- C API Use
  - [Module `memory` Source](src/lmemlib.c)
  - [Adapting Lua Standard Libraries](https://github.com/renatomaia/lua/commit/ceddb5af05061937034d8e80f4a867d7c8126831)

History
-------

### Version 2.0
- Updated to Lua 5.4.
- [Referenced](doc/manual.md#luamem_newref) (and [resizable](doc/manual.md#memorycreate-m--i--j)) memories are [closeable](http://www.lua.org/manual/5.4/manual.html#3.3.8).
- Memories now support [concat](http://www.lua.org/manual/5.4/manual.html#2.4) operator (`..`) to produce strings.
- `memory.get` now requires the indice argument `i`.
- C library and header are renamed to `*luamem.*`.
- Functions `luamem_pushresult` and `luamem_pushresultsize` are removed.
- Functions `luamem_*string` are renamed to `luamem_*array` to explicit that their result are not null-terminated.
- New function `luamem_resetref` to reset a referenced memory without releasing its current value.

### Version 1.0
- Lua module
- C Library
