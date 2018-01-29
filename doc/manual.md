Index
=====

- [`memory.create`](#memorycreate-s-i-j-)
- [`memory.resize`](#memoryresize-m-l)
- [`memory.type`](#memorytype-m)
- [`memory.len`](#memorylen-m)
- [`memory.diff`](#memorydiff-m1-m2)
- [`memory.get`](#memoryget-m-i-j-)
- [`memory.set`](#memoryset-m-i)
- [`memory.fill`](#memoryfill-m-s-i-j-o-)
- [`memory.pack`](#memorypack-m-i-fmt-v-)
- [`memory.unpack`](#memoryunpack-m-i-fmt)
- [`tostring`](#tostring-m)

Contents
========

Writable Byte Sequences
-----------------------

This library provides generic functions for manipulation of writable memory areas.
A memory can have a fixed size or be resizable.
When indexing a memory, the first byte is at position 1 (not at 0, as in C).
Indices are allowed to be negative and are interpreted as indexing backwards, from the end of the memory.
Thus, the last byte is at position -1, and so on.
In this manual we will refer to byte in position `i` as `m[i]`.

This library provides all its functions inside the table `memory`.
It also sets a metatable for the memory where the `__index` field points to the `memory` table.
Therefore, you can use the library functions in object-oriented style.
For instance, `memory.get(m,i)` can be written as `m:get(i)`, where `m` is a memory.

### `memory.create ([s [, i [, j]]])`

Creates a new fixed-size memory of `s` bytes with value zero when `s` is a number.

If `s` is a string or a memory, then the new memory will have the same size and contents of `s` from position `i` until position `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is -1 (which is the same as the size of `s`).
These indices are corrected following the same rules of function [`memory.get`](#memoryget-m-i-j).

If `s` is not provided, a resizable memory of zero bytes is created.

Returns the new memory.

### `memory.resize (m, l)`

Changes resizable memory `m` to contain `l` bytes.
All the initial bytes that fit in the new size are preserved.
Any extra bytes have value zero.

### `memory.type (m)`

Returns `"fixed"` if `m` is a fixed-size memory, or `"resizable"` if it is a resizable memory, or `nil` otherwise.

### `memory.len (m)`

Returns the size of memory `m`.

### `memory.diff (m1, m2)`

Returns the index of the first byte which values differ in `m1` and `m2`, or `nil` if both contain the same bytes.
It also returns the result of a `m1 < m2` as if they were strings.

### `memory.get (m [, i [, j]])`

Returns the values of bytes in memory `m` from `i` until `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is `i`.

If, after the translation of negative indices, `i` is less than 1, it is corrected to 1.
If `j` is greater than the size of `s`, it is corrected to that size.
If, after these corrections, `i` is greater than `j`, the range is empty and no values are returned.

### `memory.set (m, i, ...)`

Sets the values of bytes in memory `m` from position `i` with values indicated by numbers received as arguments `...`;
`i` can be negative.
If there are more arguments than bytes in the range from `i` to the end of memory `m`, the extra arguments are ignored.

### `memory.fill (m, s [, i [, j [, o]]])`

Sets the values of all bytes in memory `m` in the range from position `i` until `j` with the contents from position `o` of the string or memory `s`;
`i`, `j` and `o` can be negative.

If, after the translation of negative indices, `o` is less than 1, it is corrected to 1.
After the translation of negative indices, `i` and `j` must refer to valid positions of `m`.

If `i` is greater and `j` (empty range), or `o` refers to a position beyond the size of `s` (no contents) this function has no effect.
Otherwise, the specified contents from `s` (from `o`) are copied repeatedly until they fill all bytes in the specified range of `m` (from `i` to `j`).

If `s` is a number then all bytes in the specified range of `m` are set with the value of `s`.
The value of `o` is ignored in this case.

### `memory.pack (m, i, fmt, v...)`

Serializes in memory `m`, from position `i`, the values `v...` in binary form according to the format `fmt` (see the [Lua manual](http://www.lua.org/manual/5.3/manual.html#6.4.2)).
Returns a boolean indicating whether all values were packed in memory `m`, followed by the index of the first unwritten byte in `m` and all the values `v...` that were not packed.

### `memory.unpack (m, i, fmt)`

Returns the values encoded in position `i` of memory or string `m`, according to the format `fmt`, as in function [memory.pack](#memorypack-m-i-fmt-v-).
After the read values, this function also returns the index of the first unread byte in `m`. 

### `tostring (m)`

Returns a string with the contents of memory `m`.
