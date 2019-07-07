local memory = require "memory"
local pack = memory.pack
local packsize = string.packsize
local unpack = memory.unpack

--[[
NOTE: most of the code below is copied from the tests of Lua 5.3.1 by
      R. Ierusalimschy, L. H. de Figueiredo, W. Celes - Lua.org, PUC-Rio.

Copyright (C) 1994-2015 Lua.org, PUC-Rio.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--]]

print "testing pack/unpack"

-- maximum size for integers
local NB = 16

local sizeshort = packsize("h")
local sizeint = packsize("i")
local sizelong = packsize("l")
local sizesize_t = packsize("T")
local sizeLI = packsize("j")
local sizefloat = packsize("f")
local sizedouble = packsize("d")
local sizenumber = packsize("n")
local little = (string.pack("i2", 1) == "\1\0")
local align = packsize("!xXi16")

assert(1 <= sizeshort and sizeshort <= sizeint and sizeint <= sizelong and
       sizefloat <= sizedouble)

print("platform:")
print(string.format(
  "\tshort %d, int %d, long %d, size_t %d, float %d, double %d,\n\z
   \tlua Integer %d, lua Number %d",
   sizeshort, sizeint, sizelong, sizesize_t, sizefloat, sizedouble,
   sizeLI, sizenumber))
print("\t" .. (little and "little" or "big") .. " endian")
print("\talignment: " .. align)


-- check errors in arguments
function checkerror (msg, f, ...)
  local status, err = pcall(f, ...)
  -- print(status, err, msg)
  assert(not status and string.find(err, msg))
end

local function assertpack(sz, n, ok, pos, ...)
	assert(ok == true)
	assert(pos == sz+n)
	assert(select("#", ...) == 0)
end

local function assertunpack(sz, vals, ...)
	for i, v in ipairs(vals) do
		assert(v == select(i, ...))
	end
	assert(sz+1 == select(#vals+1, ...))
	return ...
end

print("minimum behavior for integer formats")
do
	local function testpack(fmt, val, pos)
		local sz = packsize(fmt)+pos-1
		local b = memory.create(sz)
		assertpack(sz, 1, pack(b, fmt, pos, val))
		assertunpack(sz, {val}, unpack(b, fmt, pos))
	end
	for i=1, 10 do
		testpack("B", 0xff, i)
		testpack("b", 0x7f, i)
		testpack("b", -0x80, i)
		testpack("H", 0xffff, i)
		testpack("h", 0x7fff, i)
		testpack("h", -0x8000, i)
		testpack("L", 0xffffffff, i)
		testpack("l", 0x7fffffff, i)
		testpack("l", -0x80000000, i)
	end
end

for i = 1, NB do
  -- small numbers with signal extension ("\xFF...")
  local s = string.rep("\xff", i)
  local b = memory.create(i)
  assertpack(i, 1, pack(b, "i" .. i, 1, -1))
  assert(tostring(b) == s)
  assertunpack(i, {-1}, unpack(b, "i" .. i))

  -- small unsigned number ("\0...\xAA")
  s = "\xAA" .. string.rep("\0", i - 1)
  assertpack(i, 1, pack(b, "<I" .. i, 1, 0xAA))
  assert(tostring(b) == s)
  assertunpack(i, {0xAA}, unpack(b, "<I" .. i))
  assertpack(i, 1, pack(b, ">I" .. i, 1, 0xAA))
  assert(tostring(b) == s:reverse())
  assertunpack(i, {0xAA}, unpack(b, ">I" .. i))
end

do
  local b = memory.create(sizeLI+1)
  local lnum = 0x13121110090807060504030201
  assertpack(sizeLI, 1, pack(b, "<j", 1, lnum))
  assertunpack(sizeLI, {lnum}, unpack(b, "<j"))
  memory.set(b, sizeLI+1, 0)
  assertunpack(sizeLI+1, {lnum}, unpack(b, "<i"..sizeLI+1))
  assertunpack(sizeLI+1, {lnum}, unpack(b, "<i"..sizeLI+1))

  for i = sizeLI + 1, NB do
    local b = memory.create(i)
    assertpack(sizeLI, 1, pack(b, "<j", 1, -lnum))
    assertunpack(sizeLI, {-lnum}, unpack(b, "<j"))
    -- strings with (correct) extra bytes
    memory.fill(b, 0, -(i-sizeLI))
    assertunpack(i, {-lnum}, unpack(b, "<I" .. i))
    memory.fill(b, 0xff, -(i-sizeLI))
    assertunpack(i, {-lnum}, unpack(b, "<i" .. i))
    for i = 1, memory.len(b)/2 do
      local t = memory.get(b, -i)
      memory.set(b, -i, memory.get(b, i))
      memory.set(b, i, t)
    end
    assertunpack(i, {-lnum}, unpack(b, ">i" .. i))

    -- overflows
    memory.fill(b, 0, 1, i-1)
    memory.set(b, i, 1)
    checkerror("does not fit", unpack, b, "<I" .. i)
    memory.set(b, 1, 1)
    memory.fill(b, 0, 2, i)
    checkerror("does not fit", unpack, b, ">i" .. i)
  end
end

for i = 1, sizeLI do
  local lstr = "\1\2\3\4\5\6\7\8\9\10\11\12\13"
  local lnum = 0x13121110090807060504030201
  local n = lnum & (~(-1 << (i * 8)))
  local s = string.sub(lstr, 1, i)
  local b = memory.create(i)
  assertpack(i, 1, pack(b, "<i" .. i, 1, n))
  assert(tostring(b) == s)
  assertpack(i, 1, pack(b, ">i" .. i, 1, n))
  assert(tostring(b) == s:reverse())
  assertunpack(i, {n}, unpack(b, ">i" .. i))
end

print("sign extension")
do
  local u = 0xf0
  for i = 1, sizeLI - 1 do
    local b = memory.create(i)
    memory.set(b, 1, 0xf0)
    if i>=2 then
    	memory.fill(b, 0xff, 2, i)
    end
    assertunpack(i, {-16}, unpack(b, "<i"..i))
    assertunpack(i, {u}, unpack(b, ">I"..i))
    u = u * 256 + 0xff
  end
end

print("mixed endianness")
do
  local b = memory.create(4)
  assertpack(4, 1, pack(b, ">i2 <i2", 1, 10, 20))
  assert(tostring(b) == "\0\10\20\0")
  memory.fill(b, "\10\0\0\20")
  assertunpack(4, {10, 20}, unpack(b, "<i2 >i2"))
  assertpack(4, 1, pack(b, "=i4", 1, 2001))
  local s = tostring(b)
  assertpack(4, 1, pack(b, "i4", 1, 2001))
  assert(tostring(b) == s)
end

print("invalid formats")
do
  local b = memory.create(math.max(16, NB+1))
  checkerror("out of limits", pack, b, "i0", 1, 0)
  checkerror("out of limits", pack, b, "i" .. NB + 1, 1, 0)
  checkerror("out of limits", pack, b, "!" .. NB + 1, 1, 0)
  checkerror("%(17%) out of limits %[1,16%]", pack, b, "Xi" .. NB + 1, 1)
  checkerror("invalid format option 'r'", pack, b, "i3r", 1, 0)
  memory.fill(b, 16, 1, 16)
  checkerror("16%-byte integer", unpack, b, "i16", 1)
  checkerror("not power of 2", pack, b, "!4i3", 1, 0);
  checkerror("missing size", pack, b, "c", 1, "")
end

print("overflow in packing")
for i = 1, sizeLI - 1 do
  local b = memory.create(i)
  local umax = (1 << (i * 8)) - 1
  local max = umax >> 1
  local min = ~max
  checkerror("overflow", pack, b, "<I" .. i, 1, -1)
  checkerror("overflow", pack, b, "<I" .. i, 1, min)
  checkerror("overflow", pack, b, ">I" .. i, 1, umax + 1)

  checkerror("overflow", pack, b, ">i" .. i, 1, umax)
  checkerror("overflow", pack, b, ">i" .. i, 1, max + 1)
  checkerror("overflow", pack, b, "<i" .. i, 1, min - 1)

  assertpack(i, 1, pack(b, ">i" .. i, 1, max))
  assertunpack(i, {max}, unpack(b, ">i" .. i))
  assertpack(i, 1, pack(b, "<i" .. i, 1, min))
  assertunpack(i, {min}, unpack(b, "<i" .. i))
  assertpack(i, 1, pack(b, ">I" .. i, 1, umax))
  assertunpack(i, {umax}, unpack(b, ">I" .. i))
end

print("Lua integer size")
do
  local b = memory.create(sizeLI)
  assertpack(sizeLI, 1, pack(b, ">j", 1, math.maxinteger))
  assertunpack(sizeLI, {math.maxinteger}, unpack(b, ">j"))
  assertpack(sizeLI, 1, pack(b, "<j", 1, math.mininteger))
  assertunpack(sizeLI, {math.mininteger}, unpack(b, "<j"))
  assertpack(sizeLI, 1, pack(b, "<j", 1, -1))
  assertunpack(sizeLI, {-1}, unpack(b, "<J"))  -- maximum unsigned integer
end

do
  local b1 = memory.create(sizefloat)
  local b2 = memory.create(sizefloat)
  assertpack(sizefloat, 1, pack(b1, "f", 1, 24))
  if little then
    assertpack(sizefloat, 1, pack(b2, "<f", 1, 24))
  else
    assertpack(sizefloat, 1, pack(b2, ">f", 1, 24))
  end
  assert(tostring(b1) == tostring(b2))
end

do print "testing pack/unpack of floating-point numbers" 
  local bn = memory.create(sizenumber)
  local bf = memory.create(sizefloat)
  local bd = memory.create(sizedouble)

  for _, n in ipairs{0, -1.1, 1.9, 1/0, -1/0, 1e20, -1e20, 0.1, 2000.7} do
    assertpack(sizenumber, 1, pack(bn, "n", 1, n)); assertunpack(sizenumber, {n}, unpack(bn, "n", 1))
    assertpack(sizenumber, 1, pack(bn, "<n", 1, n)); assertunpack(sizenumber, {n}, unpack(bn, "<n", 1))
    assertpack(sizenumber, 1, pack(bn, ">n", 1, n)); assertunpack(sizenumber, {n}, unpack(bn, ">n", 1))
    assertpack(sizefloat, 1, pack(bf, "<f", 1, n)); assert(tostring(bf) == string.pack(">f", n):reverse())
    assertpack(sizedouble, 1, pack(bd, ">d", 1, n)); assert(tostring(bd) == string.pack("<d", n):reverse())
  end

  -- for non-native precisions, test only with "round" numbers
  for _, n in ipairs{0, -1.5, 1/0, -1/0, 1e10, -1e9, 0.5, 2000.25} do
    assertpack(sizefloat, 1, pack(bf, "<f", 1, n)); assertunpack(sizefloat, {n}, unpack(bf, "<f", 1))
    assertpack(sizefloat, 1, pack(bf, ">f", 1, n)); assertunpack(sizefloat, {n}, unpack(bf, ">f", 1))
    assertpack(sizedouble, 1, pack(bd, "<d", 1, n)); assertunpack(sizedouble, {n}, unpack(bd, "<d", 1))
    assertpack(sizedouble, 1, pack(bd, ">d", 1, n)); assertunpack(sizedouble, {n}, unpack(bd, ">d", 1))
  end
end

print "testing pack/unpack of strings"
do
  local s = string.rep("abc", 1000)
  local sz = #s+2
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, "zB", 1, s, 247))
  assert(tostring(b) == s.."\0\xF7")
  memory.set(b, -1, 0xF9)
  assertunpack(sz, {s, 249}, unpack(b, "zB", 1))

  local sz = #s+sizesize_t
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, "s", 1, s))
  assertunpack(sz, {s}, unpack(b, "s", 1))

  checkerror("does not fit", pack, b, "s1", 1, s)

  checkerror("contains zeros", pack, b, "z", 1, "alo\0");

  for i = 2, NB do
    local b = memory.create(#s+i)
    pack(b, "s"..i, 1, s)
    local s1, pos = unpack(b, "s"..i, 1)
    assert(pos == #s+i+1)
    assert(s1 == s)
  end
end

do
  local x = string.pack("s", "alo")
  checkerror("too short", unpack, memory.create(x:sub(1, -2)), "s", 1)
  checkerror("too short", unpack, memory.create("abcd"), "c5", 1)
  checkerror("out of limits", pack, memory.create(103), "s100", 1, "alo")
end

do
  local b = memory.create(0)
  assertpack(0, 1, pack(b, "c0", 1, ""))
  --TODO: pack(b, "c1", 1, "1")
  assertunpack(0, {""}, unpack(b, "c0", 1, ""))

  local b = memory.create(3)
  assertpack(3, 1, pack(b, "<! c3", 1, "abc"))
  assert(tostring(b) == "abc")

  local b = memory.create(6)
  assertpack(6, 1, pack(b, ">!4 c6", 1, "abcdef"))
  assert(tostring(b) == "abcdef")
  
  checkerror("wrong length", pack, memory.create(2), "c3", 1, "ab")
  checkerror("wrong length", pack, memory.create(5), "c5", 1, "123456")

  local b = memory.create("abcdefghi\0xyz")
  assertunpack(#b, {"abcdefghi", "xyz"}, unpack(b, "!4 z c3", 1))
end

do print("testing multiple types and sequence")
  local fmt = "<b h b f d f n i"
  local sz = packsize(fmt)
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, fmt, 1, 1,2,3,4,5,6,7,8))
  assertunpack(sz, {1,2,3,4,5,6,7,8}, unpack(b, fmt, 1))
end

do print "testing alignment"
  local b = memory.create(3)
  assertpack(3, 1, pack(b, " < i1 i2 ", 1, 2,3))
  assert(tostring(b) == "\2\3\0")   -- no alignment by default

  local fmt = ">!8 b Xh i4 i8 c1 Xi8"
  local sz = packsize(fmt)
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, ">!8 b Xh i4 i8 c1 Xi8", 1, -12,100,200,"\xEC"))
  assert(tostring(b) == "\xf4" .. "\0\0\0" ..
                        "\0\0\0\100" ..
                        "\0\0\0\0\0\0\0\xC8" .. 
                        "\xEC" .. "\0\0\0\0\0\0\0")
  assertunpack(sz, {"\xF4", 100, 200, -20}, unpack(b, ">!8 c1 Xh i4 i8 b Xi8 XI XH", 1))

  local fmt = ">!4 c3 c4 c2 z i4 c5 c2 Xi4"
  local sz = #string.pack(fmt, "abc","abcd","xz","hello",5,"world","xy")
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, fmt, 1, "abc","abcd","xz","hello",5,"world","xy"))
  assert(tostring(b) == "abcabcdxzhello\0\0\0\0\0\5worldxy\0")
  assertunpack(sz, {"abc","abcd","xz","hello",5,"world","xy"},
    unpack(b, ">!4 c3 c4 c2 z i4 c5 c2 Xh Xi4", 1))

  local fmt = " b b Xd b Xb x"
  local sz = packsize(fmt)
  local b = memory.create(sz)
  assertpack(sz, 1, pack(b, " b b Xd b Xb x", 1, 1,2,3))
  assert(tostring(b) == "\1\2\3\0")
  assertunpack(sz-1, {1,2,3}, unpack(b, "bbXdb", 1))

  local b = memory.create("0123456701234567")
  assertunpack(8, {}, unpack(b, "!8 xXi8", 1))
  assertunpack(2, {}, unpack(b, "!8 xXi2", 1))
  assertunpack(2, {}, unpack(b, "!2 xXi2", 1))
  assertunpack(2, {}, unpack(b, "!2 xXi8", 1))
  assertunpack(16, {}, unpack(b, "!16 xXi16", 1))

  checkerror("invalid next option", pack, b, "X", 1)
  checkerror("invalid next option", unpack, b, "XXi", 1, "")
  checkerror("invalid next option", unpack, b, "X i", 1, "")
  checkerror("invalid next option", pack, b, "Xc1", 1)
end

do    -- testing initial position
  local b = memory.create(string.pack("i4i4i4i4", 1, 2, 3, 4))
  for pos = 1, 16, 4 do
    local i, p = unpack(b, "i4", pos, x)
    assert(i == pos//4 + 1 and p == pos + 4)
  end

  -- with alignment
  for pos = 0, 12 do    -- will always round position to power of 2
    local i, p = unpack(b, "!4 i4", pos + 1, x)
    assert(i == (pos + 3)//4 + 1 and p == i*4 + 1)
  end

  -- negative indices
  local i, p = unpack(b, "!4 i4", -4)
  assert(i == 4 and p == 17)
  local i, p = unpack(b, "!4 i4", -7)
  assert(i == 4 and p == 17)
  local i, p = unpack(b, "!4 i4", -#b)
  assert(i == 1 and p == 5)

  -- limits
  for i = 1, #b + 1 do
    assert(unpack(b, "c0", i) == "")
  end
  checkerror("out of bounds", unpack, b, "c0", 0)
  checkerror("out of bounds", unpack, b, "c0", #b + 2)
  checkerror("out of bounds", unpack, b, "c0", -(#b + 1))
 
end

print "OK"

