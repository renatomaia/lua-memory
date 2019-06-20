Index
=====

[Lua functions](#writable-byte-sequences) | [C API](#c-library-api) | [C API](#c-library-api)
---|---|---
[`memory.create`](#memorycreate-s--i--j) | [`luamem_Unref`](#luamem_unref) | [`luamem_realloc`](#luamem_realloc)
[`memory.resize`](#memoryresize-m-l--s) | [`luamem_addvalue`](#luamem_addvalue) | [`luamem_setref`](#luamem_setref)
[`memory.type`](#memorytype-m) | [`luamem_checklenarg`](#luamem_checklenarg) | [`luamem_tomemory`](#luamem_tomemory)
[`memory.len`](#memorylen-m) | [`luamem_checkmemory`](#luamem_checkmemory) | [`luamem_tomemoryx`](#luamem_tomemoryx)
[`memory.diff`](#memorydiff-m1-m2) | [`luamem_checkstring`](#luamem_checkstring) | [`luamem_tostring`](#luamem_tostring)
[`memory.get`](#memoryget-m--i--j) | [`luamem_free`](#luamem_free) | [`luamem_type`](#luamem_type)
[`memory.set`](#memoryset-m-i-) | [`luamem_ismemory`](#luamem_ismemory) |
[`memory.fill`](#memoryfill-m-s--i--j--o) | [`luamem_isstring`](#luamem_isstring) | [`LUAMEM_ALLOC`](#luamem_newalloc)
[`memory.find`](#memoryfind-m-s--i--j--o) | [`luamem_newalloc`](#luamem_newalloc) | [`LUAMEM_REF`](#luamem_newref)
[`memory.pack`](#memorypack-m-fmt-i-v) | [`luamem_newref`](#luamem_newref) | [`LUAMEM_TALLOC`](#luamem_tomemoryx)
[`memory.unpack`](#memoryunpack-m-fmt--i) | [`luamem_pushresult`](#luamem_pushresult) | [`LUAMEM_TNONE`](#luamem_tomemoryx)
[`memory.tostring`](#memorytostring-m--i--j) | [`luamem_pushresultsize`](#luamem_pushresultsize)| [`LUAMEM_TREF`](#luamem_tomemoryx)

Contents
========

Writable Byte Sequences
-----------------------

This library provides generic functions for manipulation of writable memory areas.
A memory can have a fixed size or be resizable.
When indexing a memory, the first byte is at position 1 (not at 0, as in C).
Indices are allowed to be negative and are interpreted as indexing backwards, from the end of the memory.
Thus, the last byte is at position -1, and so on.

This library provides all its functions inside the table `memory`.
It also sets a metatable for the memory where the `__index` field points to the `memory` table.
Therefore, you can use the library functions in object-oriented style.
For instance, `memory.get(m,i)` can be written as `m:get(i)`, where `m` is a memory.

### `memory.create ([s [, i [, j]]])`

If `s` is a number, creates a new fixed-size memory of `s` bytes with value zero.

If `s` is a string or a memory, then the new memory will have the same size and contents of `s` from position `i` until position `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is -1 (which is the same as the size of `s`).
These indices are corrected following the same rules of function [`memory.get`](#memoryget-m-i-j).

If `s` is not provided, a resizable memory of zero bytes is created.

Returns the new memory.

### `memory.resize (m, l [, s])`

Changes resizable memory `m` to contain `l` bytes.
All the initial bytes that fit in the new size are preserved.
Any extra bytes are set with the contents of string `s` if provided, or they are set to value zero otherwise.

### `memory.type (m)`

Returns `"fixed"` if `m` is a fixed-size memory, or `"resizable"` if it is a resizable memory, or `other` if it is an external memory created using the C API.
Otherwise it returns `nil`.

### `memory.len (m)`

Returns the size of memory `m`.

### `memory.diff (m1, m2)`

Returns the index of the first byte which values differ in `m1` and `m2`, or `nil` if both contain the same bytes.
It also returns the result of a `m1 < m2` as if they were strings.

Both `m1` and `m2` shall be memory or string.

### `memory.find (m, s [, i [, j [, o]]])`

Searches in memory or string `m` from position `i` until `j` for the contents of the memory or string `s` from position `o` of `s`;
`i`, `j` and `o` can be negative.
The default value for `i` and `o` is 1;
the default value for `j` is -1 (which is the same as the size of `s`).
These indices are corrected following the same rules of function [`memory.get`](#memoryget-m-i-j).

If, after the translation of negative indices, `o` is less than 1, it is corrected to 1.
After the translation of negative indices, `i` and `j` must refer to valid positions of `m`.

If `i` is greater and `j` (empty range), or `o` refers to a position beyond the size of `s` (no contents), or the bytes from `s` are not found in `m` this function returns `nil`.
Otherwise, it return the position of the first byte found in `m`.

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

Sets the values of all bytes in memory `m` from position `i` until `j` with the contents of the memory or string `s` from position `o` of `s`;
`i`, `j` and `o` can be negative.

These indices are corrected following the same rules of function [`memory.find`](#memoryfind-m-s-i-j-o-).

If `i` is greater and `j` (empty range), or `o` refers to a position beyond the size of `s` (no contents) this function has no effect.
Otherwise, the specified contents from `s` (from `o`) are copied repeatedly until they fill all bytes in the specified range of `m` (from `i` to `j`).

If `s` is a number then all bytes in the specified range of `m` are set with the value of `s`.
The value of `o` is ignored in this case.

### `memory.tostring (m [, i [, j]])`

Returns a string with the contents of memory or string `m` from `i` until `j`;
`i` and `j` can be negative.
The default value for `i` is 1;
the default value for `j` is -1 (which is the same as the size of `m`).

### `memory.pack (m, fmt, i, v...)`

Serializes in memory `m`, from position `i`, the values `v...` in binary form according to the format `fmt` (see the [Lua manual](http://www.lua.org/manual/5.3/manual.html#6.4.2)).
Returns a boolean indicating whether all values were packed in memory `m`, followed by the index of the first unwritten byte in `m` and all the values `v...` that were not packed.

### `memory.unpack (m, fmt [, i])`

Returns the values encoded in position `i` of memory or string `m`, according to the format `fmt`, as in function [memory.pack](#memorypack-m-i-fmt-v-);
The default value for `i` is 1.
After the read values, this function also returns the index of the first unread byte in `m`. 

C Library API
-------------

This section describes the C API provided as a separate library to create and manipulate memory areas from C.
There are two distinct types of memory areas in the C API:

- __allocated__: points to a constant block address with fixed size, which is automatically released when the memory is garbage collected (see [`luamem_newalloc`](#luamem_newalloc)).
- __referenced__: points to a memory area with block address and size provided by the application, which can provide a unrefering function to be used to free the memory area when it is not pointed by the Lua memory object anymore (see [`luamem_newref`](#luamem_newref)).

### `luamem_newalloc`

```C
char *luamem_newalloc (lua_State *L, size_t len);
```

Creates and pushes onto the stack a new allocated memory with the given size, and returns its block address.

Allocated memory areas uses metatable created with name given by constant `LUAMEM_ALLOC` (see [`luaL_newmetatable`](http://www.lua.org/manual/5.3/manual.html#luaL_newmetatable)).

### `luamem_Unref`

```C
typedef void (*luamem_Unref) (lua_State *L, void *mem, size_t len);
```

Type for memory unrefering functions.

These functions are called whenever a referenced memory ceases to pointo to block address `mem` which have size of `len` bytes. (see [`luamem_setref`](#luamem_setref)).

### `luamem_newref`

```C
void luamem_newref (lua_State *L);
```

Creates and pushes onto the stack a new reference memory pointing to NULL, with length zero, and no unrefering function (see [`luamem_Unref`](#luamem_Unref)).

Referenced memory areas uses metatable created with name given by constant `LUAMEM_REF` (see [`luaL_newmetatable`](http://www.lua.org/manual/5.3/manual.html#luaL_newmetatable)).

### `luamem_setref`

```C
int luamem_setref (lua_State *L, int idx, char *mem, size_t len, luamem_Unref unref);
```

Defines the block address (`mem`), size (`len`), and unrefering function (`unref`) of the referenced memory at index `idx`, and returns 1.
If `idx` does not contain a referenced memory it returns 0;

If `unref` is not `NULL`, it will be called when the memory ceases to point to this block address, either by being garbage collected or if it is updated to point to another block address (by a future call of `luamem_setref`).

If `mem` points to the same block address currently pointed by referenced memory at index `idx` then the unrefering function previously registered is not invoked.
Therefore, to avoid the call of the current unrefering function of memory at index `idx` you can do:

```C
size_t len;
char *mem = luamem_tomemory(L, idx, &len);
luamem_setref(L, idx, mem, len, NULL);  /* only update `unref` to NULL */
```

### `luamem_type`

```C
int luamem_type(lua_State *L, int idx);
```

Returns `LUAMEM_TREF` if the value at the given index is a referenced memory, or `LUAMEM_TALLOC` in case of an allocated memory, or `LUAMEM_TNONE` otherwise.

### `luamem_ismemory`

```C
int luamem_ismemory (lua_State *L, int idx);
```

Returns 1 if the value at the given index is a memory (allocated or referenced), and 0 otherwise. 

### `luamem_tomemory`

```C
char *luamem_tomemory (lua_State *L, int idx, size_t *len);
```

Equivalent to `luamem_tomemoryx(L, idx, len, NULL, NULL)`.

### `luamem_tomemoryx`

```C
char *luamem_tomemoryx (lua_State *L, int idx, size_t *len, luamem_Unref *unref, int *type);
```

Return the block address of memory at the given index, or `NULL` if the value is not a memory.

If `len` is not `NULL`, it sets `*len` with the memory size.
If `unref` is not `NULL`, it sets `*unref` with the unrefering function if the value is a referenced memory, or `NULL` otherwise.
If `type` is not `NULL`, it sets `*type` with `LUAMEM_TREF` if the value is referenced memory, or `LUAMEM_TALLOC` in case of an allocated memory, or `LUAMEM_TNONE` otherwise.

Because Lua has garbage collection, there is no guarantee that the pointer returned by `luamem_tomemory` will be valid after the corresponding Lua value is removed from the stack.

### `luamem_checkmemory`

```C
char *luamem_checkmemory (lua_State *L, int arg, size_t *len);
```

Checks whether the function argument `arg` is a memory (allocated or referenced) and returns a pointer to its contents;
if `len` is not `NULL` fills `*len` with the memory's length.

### `luamem_isstring`

```C
int luamem_isstring (lua_State *L, int idx);
```

Returns 1 if the value at the given index is a memory or string, and 0 otherwise.

### `luamem_tostring`

```C
const char *luamem_tostring (lua_State *L, int idx, size_t *len);
```

If the value at the given index is a memory it behaves like [`luamem_tomemory`](#luamem_tomemory), but retuning a pointer to constant bytes.
Otherwise, it is equivalent to [`lua_tolstring`](http://www.lua.org/manual/5.3/manual.html#lua_tolstring).

__Note__: Unlike Lua strings, memory areas are not followed by a null byte (`'\0'`).

### `luamem_checkstring`

```C
const char *luamem_checkstring (lua_State *L, int arg, size_t *len);
```

Checks whether the function argument `arg` is a memory or string and returns a pointer to its contents;
if `len` is not `NULL` fills `*len` with the contents' length.

This function might use `lua_tolstring` to get its result, so all conversions and caveats of that function apply here.

### `luamem_checklenarg`

```C
size_t luamem_checklenarg (lua_State *L, int arg);
```

Checks whether the function argument `arg` is an integer (or can be converted to an integer) of a valid memory size and returns this integer cast to a `size_t`.

### `luamem_realloc`

```C
void *luamem_realloc (lua_State *L, void *mem, size_t old, size_t new);
```

Reallocates memory pointed by `mem` of size `old` with new size `new` using the allocation function registered by the Lua state (see [`lua_getallocf`](http://www.lua.org/manual/5.3/manual.html#lua_getallocf)).
Returns the reallocated memory.

### `luamem_free`

```C
void luamem_free (lua_State *L, void *mem, size_t sz);
```

Equivalent to `luamem_realloc(L, mem, sz, 0)`.

__Note__: Any referenced memory which uses this function as the unrefering function is considered a resizable memory by the `memory` module.

### `luamem_addvalue`

```C
void luamem_addvalue (luaL_Buffer *B);
```

Similar to [`luaL_addvalue`](http://www.lua.org/manual/5.3/manual.html#luaL_addvalue), but if the value on top of the stack is a memory, it adds its contents to the buffer without converting it to a Lua string.

### `luamem_pushresult`

```C
void luamem_pushresult (luaL_Buffer *B);
```

Similar to [`luamem_pushresult`](http://www.lua.org/manual/5.3/manual.html#luaL_pushresult), but leaves a memory with the buffer contents on the top of the stack instead of a string.

### `luamem_pushresultsize`

```C
void luamem_pushresultsize (luaL_Buffer *B, size_t sz);
```

Equivalent to the sequence [`luaL_addsize`](http://www.lua.org/manual/5.3/manual.html#luaL_addsize), [`luamem_pushresult`](#luamem_pushresult).
