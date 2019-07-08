local memory = require "memory"

local maxi, mini = math.maxinteger, math.mininteger

local NB = 16  -- maximum size for integers
local sizeLI = string.packsize("j")

local function asserterr(msg, f, ...)
	local ok, err = pcall(f, ...)
	assert(not ok)
	assert(string.find(err, msg, 1, true) ~= nil)
end

local function assertret(expected, ...)
	for i, v in ipairs(expected) do
		assert(v == select(i, ...), string.format("%s ~= %s", tostring(v), tostring(select(i,...))))
	end
	assert(#expected+1 == select("#", ...))
	return select(#expected+1, ...)
end

local function testpack(case, ...)
	local packed = string.pack(case, ...)
	local size = #packed
	for _, extra in ipairs{ 0, 8, 16 } do
		local pad = string.rep("\0", extra)
		for _, spec in ipairs{
			{ prefix = "", suffix = pad },
			{ prefix = pad, suffix = "" },
			{ prefix = pad, suffix = pad }
		} do
			local index = 1+#spec.prefix
			local expected = spec.prefix..packed..spec.suffix
			local mem = memory.create(#expected)

			local options = string.match(case, "^%S*")
			local ok, pos, i = nil, index, 1
			for format in string.gmatch(case, "%s(%S+)") do
				ok, pos = memory.pack(mem, options..format, pos, select(i, ...))
				assert(ok == (#mem>0 or kind~="resizable"))  -- TODO: bug?
				-- TODO: test attempt to pack with not enough space.
				i = i+1
			end
			assert(pos == index+size)
			assert(tostring(mem) == expected)
			pos, i = index, 1
			local sequence = {nil}
			for format in string.gmatch(case, "%s%S+") do
				sequence[1] = select(i, ...)
				pos = assertret(sequence, memory.unpack(mem, options..format, pos))
				i = i+1
			end

			local format, replaces = case, i-2
			while replaces > 0 do
				memory.fill(mem, 0)
				local ok, pos = memory.pack(mem, format, index, ...)
				assert(ok == true)
				assert(pos == index+size)
				assert(tostring(mem) == expected)
				local pos = assertret({...}, memory.unpack(mem, format, index))
				assert(pos == index+size)
				format, replaces = string.gsub(format, " ", "")
			end

			if extra == 0 then break end
		end
	end
end

-- memory.type(string), memory:set(i, d), memory:get(i)
local checkmodifiable do
	local allchars = {}
	for i = 255, 0, -1 do
		allchars[#allchars+1] = string.char(i)
	end
	allchars = table.concat(allchars)
	local types = {
		fixed = true,
		resizable = true,
	}
	function checkmodifiable(b, size)
		assert(types[memory.type(b)] ~= nil)
		assert(memory.len(b) == size)
		assert(#b == size)
		for i = 1, size do
			memory.set(b, i, math.max(0, 256-i))
		end
		for i = 1, size do
			assert(memory.get(b, i) == math.max(0, 256-i))
		end
		local expected = (size > #allchars)
			and allchars..string.rep("\0", size - #allchars)
			or allchars:sub(1, size)
		assert(memory.diff(b, expected) == nil)
	end
end

local function newresizable(s, i, j)
	local m = memory.create()
	if type(s) == "number" then
		memory.resize(m, s)
	elseif s ~= nil then
		s = string.sub(tostring(s), i or 1, j)
		memory.resize(m, #s, s)
	end
	return m
end

do print("memory.type(value)")
	assert(memory.type(nil) == nil)
	assert(memory.type(true) == nil)
	assert(memory.type(false) == nil)
	assert(memory.type(0) == nil)
	assert(memory.type(2^70) == nil)
	assert(memory.type('123') == nil)
	assert(memory.type({}) == nil)
	assert(memory.type(function () end) == nil)
	assert(memory.type(print) == nil)
	assert(memory.type(coroutine.running()) == nil)
	assert(memory.type(io.stdout) == nil)
	assert(memory.type(memory.create()) == "resizable")
	assert(memory.type(memory.create(10)) == "fixed")
	assert(memory.type(memory.create("abc")) == "fixed")
	assert(memory.type(memory.create("Lua Memory 1.0", 5, -5)) == "fixed")
end

for kind, newmem in pairs{fixedsize=memory.create, resizable=newresizable} do
	local memory = setmetatable({ create = newmem }, { __index = memory })

	do print(kind, "memory:set(i, d)")
		local b = memory.create(10)
		asserterr("value out of range", memory.set, b, 1, 256)
		asserterr("value out of range", memory.set, b, 1, 511)
		asserterr("value out of range", memory.set, b, 1, -1)
	end

	do print(kind, "memory.create(string), memory.diff, memory.len, #memory")
		local function check(data, str, expi, explt)
			local b = memory.create(data)
			local i, lt = memory.diff(b, str)
			assert(i == expi)
			assert(lt == explt)
			local i, lt = memory.diff(b, memory.create(str))
			assert(i == expi)
			assert(lt == explt)
			checkmodifiable(b, #data)
		end
		check('alo', 'alo1', 4, true)
		check('', 'a', 1, true)
		check('alo\0alo', 'alo\0b', 5, true)
		check('alo\0alo\0\0', 'alo\0alo\0', 9, false)
		check('alo', 'alo\0', 4, true)
		check('alo\0', 'alo', 4, false)
		check('\0', '\1', 1, true)
		check('\0\0', '\0\1', 2, true)
		check('\1\0a\0a', '\1\0a\0a', nil, false)
		check('\1\0a\0b', '\1\0a\0a', 5, false)
		check('\0\0\0', '\0\0\0\0', 4, true)
		check('\0\0\0\0', '\0\0\0', 4, false)
		check('\0\0\0', '\0\0\0\0', 4, true)
		check('\0\0\0', '\0\0\0', nil, false)
		check('\0\0b', '\0\0a\0', 3, false)
	end

	do print(kind, "memory.create(size)")
		local function check(size)
			checkmodifiable(memory.create(size), size)
		end
		check(0)
		check(1)
		check(2)
		check(100)
		check(8192)
	end

	do print(kind, "memory.create(memory|string [, i [, j]]), memory.tostring(memory, [, i [, j]])")
		local function check(expected, data, ...)
			local b = memory.create(data, ...)
			assert(memory.diff(b, expected) == nil)
			checkmodifiable(b, #expected)
			local b = memory.create(memory.create(data), ...)
			assert(memory.diff(b, expected) == nil)
			checkmodifiable(b, #expected)
			assert(memory.tostring(memory.create(data), ...) == expected)
		end
		check(""         , "")
		check(""         , "", 1)
		check(""         , "", 1, -1)
		check(""         , "", mini, maxi)
		check("234"      , "123456789",2,4)
		check("789"      , "123456789",7)
		check(""         , "123456789",7,6)
		check("7"        , "123456789",7,7)
		check(""         , "123456789",0,0)
		check("123456789", "123456789",-10,10)
		check("123456789", "123456789",1,9)
		check(""         , "123456789",-10,-20)
		check("9"        , "123456789",-1)
		check("6789"     , "123456789",-4)
		check("456"      , "123456789",-6, -4)
		check("123456"   , "123456789", mini, -4)
		check("123456789", "123456789", mini, maxi)
		check(""         , "123456789", mini, mini)
		check("234"      , "\000123456789",3,5)
	end

	do print(kind, "memory:find(string [, i [, j [, o]]])")
		for _, C1 in ipairs({tostring, memory.create}) do
			for _, C2 in ipairs({tostring, memory.create}) do
				local m = C1"1234567890123456789"
				local e = C1""
				local s = C2"345"
				assert(memory.find(m, s) == 3)
				local a, b = memory.find(m, s)
				assert(a == 3)
				assert(b == 5, b)
				assert(memory.find(m, s, 3) == 3)
				assert(memory.find(m, s, 4) == 13)
				assert(memory.find(m, C2"346", 4) == nil)
				assert(memory.find(m, s, -9) == 13)
				assert(memory.find(m, s, 5, 1) == nil)
				assert(memory.find(m, C2"\0", 5) == nil)
				assert(memory.find(m, s, 1, -1, 4) == nil)
				assert(memory.find(m, s, 20, 30) == nil)
				assert(memory.find(m, s, -30, -20) == nil)
				assert(memory.find(e, s, 1, -1, 4) == nil)
				assert(memory.find(e, C2"") == nil)
				assert(memory.find(e, C2"", 1) == nil)
				assert(memory.find(e, C2"", 2) == nil)
				assert(memory.find(e, C2"aaa", 1) == nil)
			end
		end
	end

	do print(kind, "memory:fill(string [, i [, j]])")
		local data = string.rep(" ", 10)
		local full = "1234567890ABCDEF"
		local function fillup(space)
			return full:sub(1, #space)
		end
		local function check(expected, i, j)
			for _, S in ipairs({tostring, memory.create}) do
				local b = memory.create(data)
				memory.fill(b, S"", i, j)
				assert(memory.diff(b, data) == nil)
				memory.fill(b, S"xuxu", i, j, 5)
				assert(memory.diff(b, data) == nil)
				memory.fill(b, S"abc", i, j)
				assert(memory.diff(b, expected) == nil)
				memory.fill(b, 0x55, i, j)
				assert(memory.diff(b, expected:gsub("%S", "\x55")) == nil)
				memory.fill(b, S"XYZ", i, j, 3)
				assert(memory.diff(b, expected:gsub("%S", "Z")) == nil)
				memory.fill(b, S"XYZ", i, j, -1)
				assert(memory.diff(b, expected:gsub("%S", "Z")) == nil)
				memory.fill(b, S(full), i, j)
				assert(memory.diff(b, expected:gsub("%S+", fillup)) == nil)
			end
		end
		check("abcabcabca")
		check("abcabcabca", 1)
		check("abcabcabca", 1, -1)
		check(" abc      ", 2, 4)
		check("      abca", 7)
		check("          ", 7, 6)
		check("      a   ", 7, 7)
		check("abcabcabca",-10, 10)
		check("          ",-10,-20)
		check("abcabcabc ", 1, 9)
		check("         a",-1)
		check("      abca",-4)
		check("    abc   ",-6, -4)
		local function check(...)
			local b = memory.create(data)
			asserterr("index out of bounds", memory.fill, b, "xuxu", ...)
		end
		check( mini, maxi)
		check( mini, mini)
		check( mini, maxi)
		check( 0, 0)
		check( mini, -4)
		check( 3, maxi)
		do
			local b = memory.create(full)
			memory.fill(b, b)
			assert(memory.diff(b, full) == nil)
		end
		do
			local b = memory.create(full)
			memory.fill(b, 0)
			assert(memory.diff(b, string.rep("\0", #full)) == nil)
		end
		do
			local b = memory.create(full)
			memory.fill(b, b, 11, -1)
			assert(memory.diff(b, "1234567890123456") == nil)
		end
		do
			local b = memory.create(full)
			memory.fill(b, b, 1, 6, 11)
			assert(memory.diff(b, "ABCDEF7890ABCDEF") == nil)
		end
		do
			local b = memory.create(full)
			memory.fill(b, b, 1, 10, 7)
			assert(memory.diff(b, "7890ABCDEFABCDEF") == nil)
		end
		do
			local b = memory.create(full)
			memory.fill(b, b, 7, -1)
			assert(memory.diff(b, "1234561234567890") == nil)
		end
	end

	--[[
	NOTE: most of the test cases below are adapted from the tests of Lua 5.3.1 by
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

	testpack(" B", 0xff)
	testpack(" b", 0x7f)
	testpack(" b", -0x80)
	testpack(" H", 0xffff)
	testpack(" h", 0x7fff)
	testpack(" h", -0x8000)
	testpack(" L", 0xffffffff)
	testpack(" l", 0x7fffffff)
	testpack(" l", -0x80000000)

	for i = 1, NB do
		-- small numbers with signal extension ("\xFF...")
		testpack(" i"..i, -1)
		-- small unsigned number ("\0...\xAA")
		testpack("< I"..i, 0xAA)
		testpack("> I"..i, 0xAA)
	end

	do print(kind, "memory.pack/unpack: large integers")
		local lnum = 0x13121110090807060504030201
		testpack("< j", lnum)
		testpack("< j", -lnum)
		testpack("< i"..sizeLI+1, lnum)

		for i = sizeLI + 1, NB do
			-- strings with (correct) extra bytes
			testpack("< I"..i, -lnum)
			testpack("< i"..i, -lnum)
			testpack("> i"..i, -lnum)

			--TODO: move this to an error section about: overflows
			local mem = memory.create(i)
			memory.set(mem, i, 1)
			asserterr("does not fit", memory.unpack, mem, "<I"..i)
			memory.fill(mem, 0)
			memory.set(mem, 1, 1)
			asserterr("does not fit", memory.unpack, mem, ">i"..i)
		end

		for i = 1, sizeLI do
			local n = lnum&(~(-1<<(i*8)))
			testpack("< i"..i, n)
			testpack("> i"..i, n)
		end
	end

	do print(kind, "memory.pack/unpack: sign extension")
		local u = 0xf0
		for i = 1, sizeLI - 1 do
			testpack("< i"..i, -16)
			testpack("> I"..i, u)
			u = u<<8|0xff
		end
	end

	do print(kind, "memory.pack/unpack: mixed endianness")
		testpack(" >i2 <i2 =i4", 10, 20, 2001)
	end

	do print(kind, "memory.pack/unpack: invalid formats")
		local data = string.rep("\x55", math.max(16, NB+1))
		local mem = memory.create(data)
		asserterr("out of limits", memory.pack, mem, "i0", 1, 0)
		asserterr("out of limits", memory.pack, mem, "i"..NB+1, 1, 0)
		asserterr("out of limits", memory.pack, mem, "!"..NB+1, 1, 0)
		asserterr("(17) out of limits [1,16]", memory.pack, mem, "Xi"..NB+1, 1)
		asserterr("invalid format option 'r'", memory.pack, mem, "i3r", 1, 0x555555, 0)
		asserterr("16-byte integer", memory.unpack, mem, "i16")
		asserterr("not power of 2", memory.pack, mem, "!4i3", 1, 0)
		asserterr("missing size", memory.pack, mem, "c", 1, "")
		assert(tostring(mem) == data)
	end

	do print(kind, "memory.pack/unpack: overflow in packing")
		for i = 1, sizeLI - 1 do
			local mem = memory.create(i)
			local umax = (1 << (i * 8)) - 1
			local max = umax >> 1
			local min = ~max
			asserterr("overflow", memory.pack, mem, "<I"..i, 1, -1)
			asserterr("overflow", memory.pack, mem, "<I"..i, 1, min)
			asserterr("overflow", memory.pack, mem, ">I"..i, 1, umax+1)
			asserterr("overflow", memory.pack, mem, ">i"..i, 1, umax)
			asserterr("overflow", memory.pack, mem, ">i"..i, 1, max+1)
			asserterr("overflow", memory.pack, mem, "<i"..i, 1, min-1)

			testpack("> i"..i, max)
			testpack("< i"..i, min)
			testpack("> I"..i, umax)
		end
	end


	do print(kind, "memory.pack/unpack: Lua integer size")
		local b = memory.create(sizeLI)
		testpack("> j", math.maxinteger)
		testpack("< j", math.mininteger)
		testpack("< j", -1)  -- maximum unsigned integer
	end

	do print(kind, "memory.pack/unpack: floating-point numbers")
		for _, n in ipairs{-1.1, 1.9, 1e20, -1e20, 0.1, 2000.7} do
			testpack(" n", n)
			testpack("< n", n)
			testpack("> n", n)
		end
		-- for non-native precisions, test only with "round" numbers
		for _, n in ipairs{0, -1.5, 1/0, -1/0, 1e10, -1e9, 0.5, 2000.25} do
			testpack(" n f d", n, n, n)
			testpack("< n f d", n, n, n)
			testpack("> n f d", n, n, n)
		end
	end


	do print(kind, "memory.pack/unpack: strings")
		local s = string.rep("abc", 1000)
		testpack(" z B", s, 247)
		testpack(" z B", s, 249)
		testpack(" s", s)

		local mem = memory.create(#s+1)
		asserterr("does not fit", memory.pack, mem, "s1", 1, s)
		asserterr("contains zeros", memory.pack, mem, "z", 1, "alo\0");

		-- create memory with no '\0' after its end
		local nozero = memory.create()
		memory.resize(nozero, 3003, "abc")
		memory.resize(nozero, 3000)
		local ok, pos = memory.pack(mem, "z", 1, nozero)
		assert(ok == true)
		assert(pos == 3002)
		assert(tostring(mem) == s.."\0");

		for i = 2, NB do
			testpack(" s"..i, s)
		end
	end

	do
		local x = string.pack("s", "alo")
		asserterr("too short", memory.unpack, memory.create(x:sub(1, -2)), "s")
		asserterr("too short", memory.unpack, memory.create("abcd"), "c5")
		asserterr("out of limits", memory.pack, memory.create(103), "s100", 1, "alo")
	end

	do
		testpack(" c0", "")
		testpack("<! c3", "abc")
		testpack(">!4 c6", "abcdef")
		testpack("!4 z c3", "abcdefghi", "xyz")

		asserterr("wrong length", memory.pack, memory.create(2), "c3", 1, "ab")
		asserterr("wrong length", memory.pack, memory.create(6), "c5", 1, "123456")
	end

	do print(kind, "memory.pack/unpack: multiple types and sequence")
		testpack("< b h b f d f n i", 1, 2, 3, 4, 5, 6, 7, 8)
	end

	do print(kind, "memory.pack/unpack: alignment")
		testpack("< i1 i2 ", 2, 3)

		testpack(">!8 bXh i4 i8 c1Xi8", -12, 100, 200, "\xEC")
		testpack(">!8 c1Xh i4 i8 bXi8XIXH", "\xF4", 100, 200, -20)
		testpack(">!4 c3 c4 c2 z i4 c5 c2 Xi4",
		         "abc", "abcd", "xz", "hello", 5, "world", "xy")
		testpack(">!4 c3 c4 c2 z i4 c5 c2XhXi4",
		         "abc", "abcd", "xz", "hello", 5, "world", "xy")
		testpack(" b bXd bXbx", 1, 2, 3)
		testpack(" b bXd b", 1, 2, 3)

		local mem = memory.create("0123456701234567")
		assert(assertret({}, memory.unpack(mem, "!8 xXi8")) == 9)
		assert(assertret({}, memory.unpack(mem, "!8 xXi2")) == 3)
		assert(assertret({}, memory.unpack(mem, "!2 xXi2")) == 3)
		assert(assertret({}, memory.unpack(mem, "!2 xXi8")) == 3)
		assert(assertret({}, memory.unpack(mem, "!16 xXi16")) == 17)

		asserterr("invalid next option", memory.pack, mem, "X", 1)
		asserterr("invalid next option", memory.pack, mem, "Xc1", 1)
		asserterr("invalid next option", memory.unpack, mem, "XXi")
		asserterr("invalid next option", memory.unpack, mem, "X i")
	end

	-- TODO: review the cases below to apply then to 'unpack'.
	do print(kind, "memory.pack/unpack: initial position")
		local mem = memory.create(string.pack("i4i4i4i4", 1, 2, 3, 4))

		-- with alignment
		for pos = 0, 12 do  -- will always round position to power of 2
			local i, p = memory.unpack(mem, "!4 i4", pos+1)
			assert(i == (pos+3)//4+1 and p == i*4+1)
		end

		-- negative indices
		local i, p = memory.unpack(mem, "!4 i4", -4)
		assert(i == 4 and p == 17)
		local i, p = memory.unpack(mem, "!4 i4", -7)
		assert(i == 4 and p == 17)
		local i, p = memory.unpack(mem, "!4 i4", -#mem)
		assert(i == 1 and p == 5)

		-- limits
		for i = 1, #mem+1 do
			assert(memory.unpack(mem, "c0", i) == "")
		end
		asserterr("out of bounds", memory.unpack, mem, "c0", 0)
		asserterr("out of bounds", memory.unpack, mem, "c0", #mem+2)
		asserterr("out of bounds", memory.unpack, mem, "c0", -(#mem+1))
	end
end

do print "memory.resize(m, size [, s])"
	local m = memory.create(3)
	asserterr("resizable memory expected", memory.resize, m, 10)

	local m = memory.create()
	assert(memory.len(m) == 0)
	assert(memory.tostring(m) == "")

	memory.resize(m, 10)
	assert(tostring(m) == string.rep('\0', 10))

	memory.fill(m, "abcde")
	memory.resize(m, 15)
	assert(tostring(m) == "abcdeabcde\0\0\0\0\0")

	memory.resize(m, 5)
	assert(tostring(m) == "abcde")

	memory.resize(m, 0)
	assert(tostring(m) == "")

	memory.resize(m, 5, "abcde")
	assert(tostring(m) == "abcde")

	memory.resize(m, 10, "xyz")
	assert(tostring(m) == "abcdexyzxy")

	memory.resize(m, 5, "123")
	assert(tostring(m) == "abcde")

	memory.resize(m, 10, "")
	assert(tostring(m) == "abcde\0\0\0\0\0")

	asserterr("string or memory expected", memory.resize, m, 15, table)
	assert(tostring(m) == "abcde\0\0\0\0\0")

	asserterr("string or memory expected", memory.resize, m, 0, table)
	assert(tostring(m) == "abcde\0\0\0\0\0")
end

print "OK"
