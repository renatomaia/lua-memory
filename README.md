Lua Memory
==========

The purpose of this project is to support manipulation of memory areas in Lua.
These memory areas are much like Lua strings, but their contents can be modified in place and have an identity (selfness) independent from their contents.
The library provides the following functionalities:

- Support for writable memory areas.
- C API to manipulate strings or memory areas in a unified way.

Documentation
-------------

- [License](LICENSE)
- [Manual](doc/manual.md)
- [Demos](demo/)
  - [Create Fixed-Size Memory](demo/fixed.lua)
  - [Create Resizable Memory](demo/resizable.lua)
  - [Change Contents](demo/fill.lua)
  - [Inspect Contents](demo/inspect.lua)
  - [Compare Contents](demo/compare.lua)
  - [(Un)packing Data](demo/packing.lua)
- C API Use
  - [Module `memory` Source](src/lmemmod.c)
  - [Adapting Lua Standard Libraries](https://github.com/renatomaia/lua/commit/fdca74d8222b9c427ed70f232c8249f9b0999ba0)

TODO
----

- Finish adaptation of `string.pack` tests to test `memory.pack`.
- Add support for bitwise operations on the memory contents.

History
-------

- **Version 1.0**: First release.
