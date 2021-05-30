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
  - [Adapting Lua Standard Libraries](https://github.com/renatomaia/lua/commit/fdca74d8222b9c427ed70f232c8249f9b0999ba0)

History
-------

- **Version 1.0**: First release.
