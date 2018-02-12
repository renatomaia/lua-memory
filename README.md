Lua Memory
==========

The purpose of this project is to support manipulation of memory areas in Lua.
These memory areas are much like Lua strings, but their contents can be modified in place and have an identity (selfness) independent from their contents.
The library provides the following functionalities:

- Support for writable memory areas.
- C API to manipulate strings or memory areas in a unified way.

Documentation
-------------

- [Manual](doc/manual.md)
- [License](LICENSE)

TODO
----

- Finish adaptation of `string.pack` tests to test `memory.pack`.
- Add support for bitwise operations on the memory contents.

History
-------

Version 1.0:
:	First release.
