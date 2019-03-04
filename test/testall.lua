local memory = require "memory"

local maxi, mini = math.maxinteger, math.mininteger


local function checkerror(msg, f, ...)
  local s, err = pcall(f, ...)
  assert(not s and string.find(err, msg), err)
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
	else
		memory.resize(m, #s)
		memory.fill(m, s, i, j)
	end
	return m
end

for kind, newmem in pairs{fixedsize=memory.create, resizable=newresizable} do

	do print(kind, "memory.type(value)")
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

	do print(kind, "memory:set(i, d)")
		local b = memory.create(10)
		checkerror("value out of range", memory.set, b, 1, 256)
		checkerror("value out of range", memory.set, b, 1, 511)
		checkerror("value out of range", memory.set, b, 1, -1)
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
			checkerror("index out of bounds", memory.fill, b, "xuxu", ...)
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

end

do print "memory.resize(m, size [, s])"
	local m = memory.create(3)
	checkerror("resizable memory expected", memory.resize, m, 10)

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

	checkerror("string or memory expected", memory.resize, m, 15, table)
	assert(tostring(m) == "abcde\0\0\0\0\0")

	checkerror("string or memory expected", memory.resize, m, 0, table)
	assert(tostring(m) == "abcde\0\0\0\0\0")
end

print "OK"
