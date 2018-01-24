local memory = require "memory"
local pack = memory.pack
local packsize = string.packsize
local unpack = memory.unpack

do
  local function failpack(expectpos, expectvals, ok, pos, ...)
    assert(ok == false)
    assert(pos == expectpos)
    for i, value in ipairs(expectvals) do
      assert(value == select(i, ...))
    end
    assert(select("#", ...) == #expectvals)
  end

  local m = memory.create(0)
  failpack(1, {123,456,789}, pack(m, 1, "b", 123,456,789))

  local m = memory.create(10)
  memory.fill(m, 0x55)
  local values = {
    0x11111111,
    0x22222222,
    0x33333333,
    0x44444444,
  }
  local expectvals = {
    0x33333333,
    0x44444444,
  }
  failpack(9, expectvals, pack(m, 1, "i4i4i4i4", table.unpack(values)))
end

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
	assert(pos == sz+1)
	assert(select("#", ...) == 0)
end

local function assertunpack(sz, vals, ...)
	for i, v in ipairs(vals) do
		assert(v == select(i, ...))
	end
	assert(sz+1 == select(#vals+1, ...))
	return ...
end

-- minimum behavior for integer formats
do
	local function testpack(fmt, val)
		local sz = packsize(fmt)
		local b = memory.create(sz)
		assertpack(sz, 1, pack(b, 1, fmt, val))
		assertunpack(sz, {val}, unpack(b, 1, fmt))
	end
	testpack("B", 0xff)
	testpack("b", 0x7f)
	testpack("b", -0x80)
	testpack("H", 0xffff)
	testpack("h", 0x7fff)
	testpack("h", -0x8000)
	testpack("L", 0xffffffff)
	testpack("l", 0x7fffffff)
	testpack("l", -0x80000000)
end

for i = 1, NB do
  -- small numbers with signal extension ("\xFF...")
  local s = string.rep("\xff", i)
  local b = memory.create(i)
  assertpack(i, 1, pack(b, 1, "i" .. i, -1))
  assert(tostring(b) == s)
  assertunpack(i, {-1}, unpack(b, 1, "i" .. i))

  -- small unsigned number ("\0...\xAA")
  s = "\xAA" .. string.rep("\0", i - 1)
  assertpack(i, 1, pack(b, 1, "<I" .. i, 0xAA))
  assert(tostring(b) == s)
  assertunpack(i, {0xAA}, unpack(b, 1, "<I" .. i))
  assertpack(i, 1, pack(b, 1, ">I" .. i, 0xAA))
  assert(tostring(b) == s:reverse())
  assertunpack(i, {0xAA}, unpack(b, 1, ">I" .. i))
end

do
  local b = memory.create(sizeLI+1)
  local lnum = 0x13121110090807060504030201
  assertpack(sizeLI, 1, pack(b, 1, "<j", lnum))
  assertunpack(sizeLI, {lnum}, unpack(b, 1, "<j"))
  memory.set(b, sizeLI+1, 0)
  assertunpack(sizeLI+1, {lnum}, unpack(b, 1, "<i"..sizeLI+1))
  assertunpack(sizeLI+1, {lnum}, unpack(b, 1, "<i"..sizeLI+1))

  for i = sizeLI + 1, NB do
    local b = memory.create(i)
    assertpack(sizeLI, 1, pack(b, 1, "<j", -lnum))
    assertunpack(sizeLI, {-lnum}, unpack(b, 1, "<j"))
    -- strings with (correct) extra bytes
    memory.fill(b, 0, -(i-sizeLI))
    assertunpack(i, {-lnum}, unpack(b, 1, "<I" .. i))
    memory.fill(b, 0xff, -(i-sizeLI))
    assertunpack(i, {-lnum}, unpack(b, 1, "<i" .. i))
    for i = 1, memory.len(b)/2 do
      local t = memory.get(b, -i)
      memory.set(b, -i, memory.get(b, i))
      memory.set(b, i, t)
    end
    assertunpack(i, {-lnum}, unpack(b, 1, ">i" .. i))

    -- overflows
    memory.fill(b, 0, 1, i-1)
    memory.set(b, i, 1)
    checkerror("does not fit", unpack, b, 1, "<I" .. i)
    memory.set(b, 1, 1)
    memory.fill(b, 0, 2, i)
    checkerror("does not fit", unpack, b, 1, ">i" .. i)
  end
end

for i = 1, sizeLI do
  local lstr = "\1\2\3\4\5\6\7\8\9\10\11\12\13"
  local lnum = 0x13121110090807060504030201
  local n = lnum & (~(-1 << (i * 8)))
  local s = string.sub(lstr, 1, i)
  local b = memory.create(i)
  assertpack(i, 1, pack(b, 1, "<i" .. i, n))
  assert(tostring(b) == s)
  assertpack(i, 1, pack(b, 1, ">i" .. i, n))
  assert(tostring(b) == s:reverse())
  assertunpack(i, {n}, unpack(b, 1, ">i" .. i))
end

-- sign extension
do
  local u = 0xf0
  for i = 1, sizeLI - 1 do
    local b = memory.create(i)
    memory.set(b, 1, 0xf0)
    if i>=2 then
    	memory.fill(b, 0xff, 2, i)
    end
    assertunpack(i, {-16}, unpack(b, 1, "<i"..i))
    assertunpack(i, {u}, unpack(b, 1, ">I"..i))
    u = u * 256 + 0xff
  end
end

-- mixed endianness
do
  local b = memory.create(4)
  assertpack(4, 2, pack(b, 1, ">i2 <i2", 10, 20))
  assert(tostring(b) == "\0\10\20\0")
  memory.fill(b, "\10\0\0\20")
  assertunpack(4, {10, 20}, unpack(b, 1, "<i2 >i2"))
  assertpack(4, 1, pack(b, 1, "=i4", 2001))
  local s = tostring(b)
  assertpack(4, 1, pack(b, 1, "i4", 2001))
  assert(tostring(b) == s)
end

print("testing invalid formats")

do
  local b = memory.create(math.max(16, NB+1))
  checkerror("out of limits", pack, b, 1, "i0", 0)
  checkerror("out of limits", pack, b, 1, "i" .. NB + 1, 0)
  checkerror("out of limits", pack, b, 1, "!" .. NB + 1, 0)
  checkerror("%(17%) out of limits %[1,16%]", pack, b, 1, "Xi" .. NB + 1)
  checkerror("invalid format option 'r'", pack, b, 1, "i3r", 0)
  memory.fill(b, 16, 1, 16)
  checkerror("16%-byte integer", unpack, b, 1, "i16")
  checkerror("not power of 2", pack, b, 1, "!4i3", 0);
  checkerror("missing size", pack, b, 1, "c", "")
end

-- overflow in packing
for i = 1, sizeLI - 1 do
  local b = memory.create(i)
  local umax = (1 << (i * 8)) - 1
  local max = umax >> 1
  local min = ~max
  checkerror("overflow", pack, b, 1, "<I" .. i, -1)
  checkerror("overflow", pack, b, 1, "<I" .. i, min)
  checkerror("overflow", pack, b, 1, ">I" .. i, umax + 1)

  checkerror("overflow", pack, b, 1, ">i" .. i, umax)
  checkerror("overflow", pack, b, 1, ">i" .. i, max + 1)
  checkerror("overflow", pack, b, 1, "<i" .. i, min - 1)

  assertpack(i, 1, pack(b, 1, ">i" .. i, max))
  assertunpack(i, {max}, unpack(b, 1, ">i" .. i))
  assertpack(i, 1, pack(b, 1, "<i" .. i, min))
  assertunpack(i, {min}, unpack(b, 1, "<i" .. i))
  assertpack(i, 1, pack(b, 1, ">I" .. i, umax))
  assertunpack(i, {umax}, unpack(b, 1, ">I" .. i))
end

-- Lua integer size
do
  local b = memory.create(sizeLI)
  assertpack(sizeLI, 1, pack(b, 1, ">j", math.maxinteger))
  assertunpack(sizeLI, {math.maxinteger}, unpack(b, 1, ">j"))
  assertpack(sizeLI, 1, pack(b, 1, "<j", math.mininteger))
  assertunpack(sizeLI, {math.mininteger}, unpack(b, 1, "<j"))
  assertpack(sizeLI, 1, pack(b, 1, "<j", -1))
  assertunpack(sizeLI, {-1}, unpack(b, 1, "<J"))  -- maximum unsigned integer
end

do
  local b1 = memory.create(sizefloat)
  local b2 = memory.create(sizefloat)
  pack(b1, 1, "f", 24)
  if little then
    pack(b2, 1, "<f", 24)
  else
    pack(b2, 1, ">f", 24)
  end
  assert(tostring(b1) == tostring(b2))
end

do return end

print "testing pack/unpack of floating-point numbers" 

for _, n in ipairs{0, -1.1, 1.9, 1/0, -1/0, 1e20, -1e20, 0.1, 2000.7} do
    assert(unpack("n", pack("n", n)) == n)
    assert(unpack("<n", pack("<n", n)) == n)
    assert(unpack(">n", pack(">n", n)) == n)
    assert(pack("<f", n) == pack(">f", n):reverse())
    assert(pack(">d", n) == pack("<d", n):reverse())
end

-- for non-native precisions, test only with "round" numbers
for _, n in ipairs{0, -1.5, 1/0, -1/0, 1e10, -1e9, 0.5, 2000.25} do
  assert(unpack("<f", pack("<f", n)) == n)
  assert(unpack(">f", pack(">f", n)) == n)
  assert(unpack("<d", pack("<d", n)) == n)
  assert(unpack(">d", pack(">d", n)) == n)
end

print "testing pack/unpack of strings"
do
  local s = string.rep("abc", 1000)
  assert(pack("zB", s, 247) == s .. "\0\xF7")
  local s1, b = unpack("zB", s .. "\0\xF9")
  assert(b == 249 and s1 == s)
  s1 = pack("s", s)
  assert(unpack("s", s1) == s)

  checkerror("does not fit", pack, "s1", s)

  checkerror("contains zeros", pack, "z", "alo\0");

  for i = 2, NB do
    local s1 = pack("s" .. i, s)
    assert(unpack("s" .. i, s1) == s and #s1 == #s + i)
  end
end

do
  local x = pack("s", "alo")
  checkerror("too short", unpack, "s", x:sub(1, -2))
  checkerror("too short", unpack, "c5", "abcd")
  checkerror("out of limits", pack, "s100", "alo")
end

do
  assert(pack("c0", "") == "")
  assert(packsize("c0") == 0)
  assert(unpack("c0", "") == "")
  assert(pack("<! c3", "abc") == "abc")
  assert(packsize("<! c3") == 3)
  assert(pack(">!4 c6", "abcdef") == "abcdef")
  checkerror("wrong length", pack, "c3", "ab")
  checkerror("2", pack, "c5", "123456")
  local a, b, c = unpack("!4 z c3", "abcdefghi\0xyz")
  assert(a == "abcdefghi" and b == "xyz" and c == 14)
end


-- testing multiple types and sequence
do
  local x = pack("<b h b f d f n i", 1, 2, 3, 4, 5, 6, 7, 8)
  assert(#x == packsize("<b h b f d f n i"))
  local a, b, c, d, e, f, g, h = unpack("<b h b f d f n i", x)
  assert(a == 1 and b == 2 and c == 3 and d == 4 and e == 5 and f == 6 and
         g == 7 and h == 8) 
end

print "testing alignment"
do
  assert(pack(" < i1 i2 ", 2, 3) == "\2\3\0")   -- no alignment by default
  local x = pack(">!8 b Xh i4 i8 c1 Xi8", -12, 100, 200, "\xEC")
  assert(#x == packsize(">!8 b Xh i4 i8 c1 Xi8"))
  assert(x == "\xf4" .. "\0\0\0" ..
              "\0\0\0\100" ..
              "\0\0\0\0\0\0\0\xC8" .. 
              "\xEC" .. "\0\0\0\0\0\0\0")
  local a, b, c, d, pos = unpack(">!8 c1 Xh i4 i8 b Xi8 XI XH", x)
  assert(a == "\xF4" and b == 100 and c == 200 and d == -20 and (pos - 1) == #x)

  x = pack(">!4 c3 c4 c2 z i4 c5 c2 Xi4",
                  "abc", "abcd", "xz", "hello", 5, "world", "xy")
  assert(x == "abcabcdxzhello\0\0\0\0\0\5worldxy\0")
  local a, b, c, d, e, f, g, pos = unpack(">!4 c3 c4 c2 z i4 c5 c2 Xh Xi4", x)
  assert(a == "abc" and b == "abcd" and c == "xz" and d == "hello" and
         e == 5 and f == "world" and g == "xy" and (pos - 1) % 4 == 0)

  x = pack(" b b Xd b Xb x", 1, 2, 3)
  assert(packsize(" b b Xd b Xb x") == 4)
  assert(x == "\1\2\3\0")
  a, b, c, pos = unpack("bbXdb", x)
  assert(a == 1 and b == 2 and c == 3 and pos == #x)

  -- only alignment
  assert(packsize("!8 xXi8") == 8)
  local pos = unpack("!8 xXi8", "0123456701234567"); assert(pos == 9)
  assert(packsize("!8 xXi2") == 2)
  local pos = unpack("!8 xXi2", "0123456701234567"); assert(pos == 3)
  assert(packsize("!2 xXi2") == 2)
  local pos = unpack("!2 xXi2", "0123456701234567"); assert(pos == 3)
  assert(packsize("!2 xXi8") == 2)
  local pos = unpack("!2 xXi8", "0123456701234567"); assert(pos == 3)
  assert(packsize("!16 xXi16") == 16)
  local pos = unpack("!16 xXi16", "0123456701234567"); assert(pos == 17)

  checkerror("invalid next option", pack, "X")
  checkerror("invalid next option", unpack, "XXi", "")
  checkerror("invalid next option", unpack, "X i", "")
  checkerror("invalid next option", pack, "Xc1")
end

do    -- testing initial position
  local x = pack("i4i4i4i4", 1, 2, 3, 4)
  for pos = 1, 16, 4 do
    local i, p = unpack("i4", x, pos)
    assert(i == pos//4 + 1 and p == pos + 4)
  end

  -- with alignment
  for pos = 0, 12 do    -- will always round position to power of 2
    local i, p = unpack("!4 i4", x, pos + 1)
    assert(i == (pos + 3)//4 + 1 and p == i*4 + 1)
  end

  -- negative indices
  local i, p = unpack("!4 i4", x, -4)
  assert(i == 4 and p == 17)
  local i, p = unpack("!4 i4", x, -7)
  assert(i == 4 and p == 17)
  local i, p = unpack("!4 i4", x, -#x)
  assert(i == 1 and p == 5)

  -- limits
  for i = 1, #x + 1 do
    assert(unpack("c0", x, i) == "")
  end
  checkerror("out of string", unpack, "c0", x, 0)
  checkerror("out of string", unpack, "c0", x, #x + 2)
  checkerror("out of string", unpack, "c0", x, -(#x + 1))
 
end

print "OK"

