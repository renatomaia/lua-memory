Module `buffer`
===============

-- buffer support
[ok]   b = buffer.create (b|s|sz [, i [, j]])
[ok]   b:set (pos, ...)
[ok]   b:fill (b|s [, i [, j [, o]]])
[ok]   sz = #b                          -- ~ stream.len
[ok]   str = tostring (b)               -- ~ stream.tostring
[ok]   ... = b:get ([i [, j]])          -- ~ stream.byte
[??]   fmt_i, arg_i = b:pack (i, fmt, ...) -- padding shall not change buffer
[??]   ... = buffer:unpack (i, fmt [, pos])

Module `buffer.stream`
======================

-- inspect streams
[  ]   "string"|"buffer" = stream.type (b|s)
[ok]   index, lesser = stream.diff (b|s, b|s)
[ok]   sz = stream.len (b|s)
[ok]   str = stream.tostring (b|s [, i [, j]]) -- ~ string.sub
[ok]   ... = stream.byte (b|s [, i [, j]])
-- pattern matching
[??]   i, j = stream.find (b|s, pattern [, init [, plain]])
[??]   for ... in stream.gmatch (b|s, pattern) do
[??]   ... = stream.match (b|s, pattern [, init])
-- structure packing
[??]   ... = stream.unpack (fmt, b|s [, pos])
[??]   size = stream.packsize (fmt, ...)
-- stream factories (out="string"|"buffer")
[ok]   b|s = stream.char (out, ...)
[??]   b|s = stream.dump (out, f [, strip])
[??]   b|s = stream.format (out, fmt, ...)
[??]   b|s = stream.gsub (out, b|s, pattern, repl [, n])
[??]   b|s = stream.pack (out, fmt, ...)
[??]   b|s = stream.rep (out, b|s, n [, sep])
[??]   b|s = stream.lower (out, b|s) -- out="string"|"buffer"|"inplace"
[??]   b|s = stream.upper (out, b|s) -- out="string"|"buffer"|"inplace"
[??]   b|s = stream.reverse (out, b|s) -- out="string"|"buffer"|"inplace"
[  ]   b|s = stream.concat (out, list [, sep [, i [, j]]])


Legend
------
[ok] - implementation and tests
[??] - implementation only
[  ] - no implementation yet


Contents
========

Writable Fixed-Size Buffers
---------------------------

This library provides generic functions for manipulation of fixed-size memory buffers.
When indexing a buffer, the first byte is at position 1 (not at 0, as in C).
Indices are allowed to be negative and are interpreted as indexing backwards, from the end of the buffer.
Thus, the last byte is at position -1, and so on.
In this manual we will refer to byte in position `i` as `b[i]`.

This library provides all its functions inside the table `buffer`.
It also sets a metatable for the buffers where the __index field points to the `buffer` table.
Therefore, you can use the library functions in object-oriented style.
For instance, `buffer.get(b,i)` can be written as `b:get(i)`, where `b` is a buffer.

### `buffer.create (s [, i [, j]])`

Creates a new buffer of `s` bytes when `s` is a number.

If `s` is a string or a buffer, then the new buffer will have the same size and contents of `s` from position `i` until position `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is -1 (which is the same as the size of `s`).
These indices are corrected following the same rules of function [`buffer.get`](#bufferget-b-i-j).

Returns the new buffer.

### `buffer.len (b)`

Returns the size of buffer `b`.

### `buffer.tostring (b)`

Returns a string with the contents of buffer `b`.

### `buffer.get (b [, i [, j]])`

Returns the values of bytes in buffer `b` from `i` until `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is `i`.

If, after the translation of negative indices, `i` is less than 1, it is corrected to 1.
If `j` is greater than the size of `s`, it is corrected to that size.
If, after these corrections, `i` is greater than `j`, the range is empty and no values are returned.

### `buffer.set (b, i, ...)`

Sets the values of bytes in buffer `b` from position `i` with values indicated by numbers received as arguments `...`;
`i` can be negative.
If there are more arguments than bytes in the range from `i` to the end of buffer `b`, the extra arguments are ignored.

### `buffer.fill (b, s [, i [, j [, o]]])`

Sets the values of all bytes in buffer `b` in the range from position `i` until `j` with the contents from position `o` of the string or buffer `s`;
`i`, `j` and `o` can be negative.

If, after the translation of negative indices, `o` is less than 1, it is corrected to 1.
After the translation of negative indices, `i` and `j` must refer to valid positions of `b`.

If `i` is greater and `j` (empty range), or `o` refers to a position beyond the size of `b` (no contents) this function has no effect.
Otherwise, the specified contents from `s` (from `o`) are copied repeatedly until they fill all bytes in the specified range of `b` (from `i` to `j`).

If `s` is a number then all bytes in the specified range of `b` are set with the value of `s`.
The value of `o` is ignored in this case.

### `buffer.pack (b, i, fmt, v...)`

Serializes in buffer `b`, from position `i`, the values `v...` in binary form according to the format `fmt` (see the [Lua manual](http://www.lua.org/manual/5.3/manual.html#6.4.2)).
Returns the index of the first unwritten byte in `b`.

### `buffer.unpack (b, i, fmt)`

Returns the values encoded in position `i` of buffer or string `b`, according to the format `fmt`, as in function [buffer.pack](#bufferpack-b-i-fmt-v-).
After the read values, this function also returns the index of the first unread byte in `b`. 