LuaStream
=========

Seamless Support for Buffers in Lua

The main purpose of this project is to support for buffers that provide a fixed-size memory area (userdata) to be manipulated in Lua. The library introduces the concept of "stream" which is either a buffer or an ordinary Lua string. The library provides the following functionalities:

- Support for writable memory buffers.
- C API to manipulate Lua streams (string|buffer) in a unified way.
- Alternative implementations of Lua libraries that manipulate generic Lua streams (string|buffer).

TODO
----

- Make buffers provide `buffer.*` functions as methods as before.
- Assure buffers always have a `\0` at the end.
- Write the manual

Documentation
-------------

- [Manual](doc/manual.md)
- [License](LICENSE)

History
-------

Version 1.0:
:	First release.
