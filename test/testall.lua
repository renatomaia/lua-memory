-- $Id$
local buffer = require "buffer"
local stream = require "buffer.stream"

print('testing buffers and buffer functions')

local maxi, mini = math.maxinteger, math.mininteger


local function checkerror(msg, f, ...)
  local s, err = pcall(f, ...)
  assert(not s and string.find(err, msg))
end

-- testing stream.isbuffer(string)
assert(stream.isbuffer(nil) == false)
assert(stream.isbuffer(true) == false)
assert(stream.isbuffer(false) == false)
assert(stream.isbuffer(0) == false)
assert(stream.isbuffer(2^70) == false)
assert(stream.isbuffer('123') == false)
assert(stream.isbuffer({}) == false)
assert(stream.isbuffer(function () end) == false)
assert(stream.isbuffer(print) == false)
assert(stream.isbuffer(coroutine.running()) == false)
assert(stream.isbuffer(io.stdout) == false)

-- testing stream.isbuffer(string), buffer:set(i, d), buffer:get(i)
local checkmodifiable do
	local allchars = {}
	for i = 255, 0, -1 do
		allchars[#allchars+1] = string.char(i)
	end
	allchars = table.concat(allchars)
	function checkmodifiable(b, size)
		assert(stream.isbuffer(b) == true)
		assert(stream.len(b) == size)
		assert(#b == size)
		for i = 1, size do
			buffer.set(b, i, math.max(0, 256-i))
		end
		for i = 1, size do
			assert(buffer.get(b, i) == math.max(0, 256-i))
		end
		local expected = (size > #allchars)
			and allchars..string.rep("\0", size - #allchars)
			or allchars:sub(1, size)
		assert(stream.diff(b, expected) == nil)
	end
end

-- testing buffer:set(i, d)
do
	local b = buffer.create(10)
	checkerror("value out of range", buffer.set, b, 1, 256)
	checkerror("value out of range", buffer.set, b, 1, 511)
	checkerror("value out of range", buffer.set, b, 1, -1)
end

do -- testing buffer.create(string), stream.diff, stream.len, #buffer
	local function check(data, str, expi, explt)
		local b = buffer.create(data)
		local i, lt = stream.diff(b, str)
		assert(i == expi)
		assert(lt == explt)
		local i, lt = stream.diff(b, buffer.create(str))
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

do -- testing buffer.create(size)
	local function check(size)
		checkmodifiable(buffer.create(size), size)
	end
	check(0)
	check(1)
	check(2)
	check(100)
	check(8192)
end

do -- testing buffer.create(buffer|string [, i [, j]])
	local function check(expected, data, ...)
		local b = buffer.create(data, ...)
		assert(stream.diff(b, expected) == nil)
		checkmodifiable(b, #expected)
		local b = buffer.create(buffer.create(data), ...)
		assert(stream.diff(b, expected) == nil)
		checkmodifiable(b, #expected)
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

do -- testing buffer:fill(stream [, i [, j]])
	local data = string.rep(" ", 10)
	local full = "1234567890ABCDEF"
	local function fillup(space)
		return full:sub(1, #space)
	end
	local function check(expected, i, j)
		for _, S in ipairs({tostring, buffer.create}) do
			local b = buffer.create(data)
			buffer.fill(b, S"", i, j)
			assert(stream.diff(b, data) == nil)
			buffer.fill(b, S"xuxu", i, j, 5)
			assert(stream.diff(b, data) == nil)
			buffer.fill(b, S"abc", i, j)
			assert(stream.diff(b, expected) == nil)
			buffer.fill(b, 0x55, i, j)
			assert(stream.diff(b, expected:gsub("%S", "\x55")) == nil)
			buffer.fill(b, S"XYZ", i, j, 3)
			assert(stream.diff(b, expected:gsub("%S", "Z")) == nil)
			buffer.fill(b, S"XYZ", i, j, -1)
			assert(stream.diff(b, expected:gsub("%S", "Z")) == nil)
			buffer.fill(b, S(full), i, j)
			assert(stream.diff(b, expected:gsub("%S+", fillup)) == nil)
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
	check("abcabcabc ", 1, 9)
	check("         a",-1)
	check("      abca",-4)
	check("    abc   ",-6, -4)
	local function check(...)
		local b = buffer.create(data)
		checkerror("index out of bounds", buffer.fill, b, "xuxu", ...)
	end
	check( mini, maxi)
	check( mini, mini)
	check( mini, maxi)
	check( 0, 0)
	check(-10,-20)
	check( mini, -4)
	check( 3, maxi)
	do
		local b = buffer.create(full)
		buffer.fill(b, b)
		assert(stream.diff(b, full) == nil)
	end
	do
		local b = buffer.create(full)
		buffer.fill(b, 0)
		assert(stream.diff(b, string.rep("\0", #full)) == nil)
	end
	do
		local b = buffer.create(full)
		buffer.fill(b, b, 11, -1)
		assert(stream.diff(b, "1234567890123456") == nil)
	end
	do
		local b = buffer.create(full)
		buffer.fill(b, b, 1, 6, 11)
		assert(stream.diff(b, "ABCDEF7890ABCDEF") == nil)
	end
	do
		local b = buffer.create(full)
		buffer.fill(b, b, 1, 10, 7)
		assert(stream.diff(b, "7890ABCDEFABCDEF") == nil)
	end
	do
		local b = buffer.create(full)
		buffer.fill(b, b, 7, -1)
		assert(stream.diff(b, "1234561234567890") == nil)
	end
end

do -- testing stream.tostring(b|s [, i [, j]]), stream.byte(b|s [, i [, j]])
	local function check(data, ...)
		local i,j = ...
		local expected = string.sub(data, i or 1, j)
		local s = data
		assert(stream.tostring(s, ...) == expected)
		if select("#", ...) >= 2 then
			assert(string.char(stream.byte(s, ...)) == expected)
		end
		local s = buffer.create(data)
		assert(stream.tostring(s, ...) == expected)
		if select("#", ...) >= 2 then
			assert(string.char(stream.byte(s, ...)) == expected)
		end
	end
	check("a")
	check("\xe4")
	check("\255")
	check("\0")
	check("\0\0alo\0x", -1)
	check("ba", 2)
	check("\n\n", 2, -1)
	check("\n\n", 2, 2)
	check("")
	check("hi", -3)
	check("hi", 3)
	check("hi", 9, 10)
	check("hi", 2, 1)
	check("\0\255\0")
	check("\0\xe4\0")
	check("\xe4l\0óu", 1, -1)
	check("\xe4l\0óu", 1, 0)
	check("\xe4l\0óu", -10, 100)
end





--[======[
do -- testing stream.concat(out, list [, sep [, i [, j]]])
	local function makelists(list)
		local buffers = {}
		local mixed = {}
		for index, str in pairs(list) do
			local b = buffer.create(str)
			buffer[index] = b
			mixed[index] = index%2==0 and str or b
		end
		return {
			strings = list,
			buffers = buffers,
			mixed = mixed,
		}
	end
	local function check(expected, lists, ...)
		for _, list in pairs(lists) do
			local str = stream.concat("string", list, ...)
			assert(str == expected)
			local buf = stream.concat("buffer", list, ...)
			assert(stream.diff(buf, expected) == expected)
			checkmodifiable(buf)
		end
	end
	local empty = makelists{}
	check("", empty)
	check("", empty, 'x')
	check("", empty, "x", maxi, maxi - 1)
	check("", empty, "x", mini + 1, mini)
	check("", empty, "x", maxi, mini)
	check("\0.\0.\0\1.\0.\0\1\2", makelists{'\0', '\0\1', '\0\1\2'}, '.\0.')
	local a = {}; for i=1,300 do a[i] = "xuxu" end
	a = makelists(a)
	check(string.rep("xuxu", 300, "123"), a, "123")
	check("xuxu"                        , a, "b"  , 20, 20)
	check("xuxuxuxu"                    , a, ""   , 20, 21)
	check(""                            , a, "x"  , 22, 21)
	check("xuxu3xuxu"                   , a, "3"  , 299)
	check("alo"  , makelists{[maxi]="alo"             }, "x", maxi, maxi)
	check("y-alo", makelists{[maxi]="alo",[maxi-1]="y"}, "-", maxi-1, maxi)

	assert(not pcall(stream.concat, {buffer.create"a", "b", {}}))

	a = makelists{"a","b","c"}
	check("", a, ",", 1, 0)
	check("a", a, ",", 1, 1)
	check("a,b", a, ",", 1, 2)
	check("b,c", a, ",", 2)
	check("c", a, ",", 3)
	check("", a, ",", 4)
end

-- testing string.find
assert(string.find("123456789", "345") == 3)
a,b = string.find("123456789", "345")
assert(string.sub("123456789", a, b) == "345")
assert(string.find("1234567890123456789", "345", 3) == 3)
assert(string.find("1234567890123456789", "345", 4) == 13)
assert(string.find("1234567890123456789", "346", 4) == nil)
assert(string.find("1234567890123456789", ".45", -9) == 13)
assert(string.find("abcdefg", "\0", 5, 1) == nil)
assert(string.find("", "") == 1)
assert(string.find("", "", 1) == 1)
assert(not string.find("", "", 2))
assert(string.find('', 'aaa', 1) == nil)
assert(('alo(.)alo'):find('(.)', 1, 1) == 4)

-- testing string.byte/string.char
assert(string.byte("a") == 97)
assert(string.byte("\xe4") > 127)
assert(string.byte(string.char(255)) == 255)
assert(string.byte(string.char(0)) == 0)
assert(string.byte("\0") == 0)
assert(string.byte("\0\0alo\0x", -1) == string.byte('x'))
assert(string.byte("ba", 2) == 97)
assert(string.byte("\n\n", 2, -1) == 10)
assert(string.byte("\n\n", 2, 2) == 10)
assert(string.byte("") == nil)
assert(string.byte("hi", -3) == nil)
assert(string.byte("hi", 3) == nil)
assert(string.byte("hi", 9, 10) == nil)
assert(string.byte("hi", 2, 1) == nil)
assert(string.char() == "")
assert(string.char(0, 255, 0) == "\0\255\0")
assert(string.char(0, string.byte("\xe4"), 0) == "\0\xe4\0")
assert(string.char(string.byte("\xe4l\0óu", 1, -1)) == "\xe4l\0óu")
assert(string.char(string.byte("\xe4l\0óu", 1, 0)) == "")
assert(string.char(string.byte("\xe4l\0óu", -10, 100)) == "\xe4l\0óu")

assert(string.upper("ab\0c") == "AB\0C")
assert(string.lower("\0ABCc%$") == "\0abcc%$")
assert(string.rep('teste', 0) == '')
assert(string.rep('tés\00tê', 2) == 'tés\0têtés\000tê')
assert(string.rep('', 10) == '')

if string.packsize("i") == 4 then
  -- result length would be 2^31 (int overflow)
  checkerror("too large", string.rep, 'aa', (1 << 30))
  checkerror("too large", string.rep, 'a', (1 << 30), ',')
end

-- repetitions with separator
assert(string.rep('teste', 0, 'xuxu') == '')
assert(string.rep('teste', 1, 'xuxu') == 'teste')
assert(string.rep('\1\0\1', 2, '\0\0') == '\1\0\1\0\0\1\0\1')
assert(string.rep('', 10, '.') == string.rep('.', 9))
assert(not pcall(string.rep, "aa", maxi // 2))
assert(not pcall(string.rep, "", maxi // 2, "aa"))

assert(string.reverse"" == "")
assert(string.reverse"\0\1\2\3" == "\3\2\1\0")
assert(string.reverse"\0001234" == "4321\0")

for i=0,30 do assert(string.len(string.rep('a', i)) == i) end

assert(type(tostring(nil)) == 'string')
assert(type(tostring(12)) == 'string')
assert(string.find(tostring{}, 'table:'))
assert(string.find(tostring(print), 'function:'))
assert(#tostring('\0') == 1)
assert(tostring(true) == "true")
assert(tostring(false) == "false")
assert(tostring(-1203) == "-1203")
assert(tostring(1203.125) == "1203.125")
assert(tostring(-0.5) == "-0.5")
assert(tostring(-32767) == "-32767")
if 2147483647 > 0 then   -- no overflow? (32 bits)
  assert(tostring(-2147483647) == "-2147483647")
end
if 4611686018427387904 > 0 then   -- no overflow? (64 bits)
  assert(tostring(4611686018427387904) == "4611686018427387904")
  assert(tostring(-4611686018427387904) == "-4611686018427387904")
end

if tostring(0.0) == "0.0" then   -- "standard" coercion float->string
  assert('' .. 12 == '12' and 12.0 .. '' == '12.0')
  assert(tostring(-1203 + 0.0) == "-1203.0")
else   -- compatible coercion
  assert(tostring(0.0) == "0")
  assert('' .. 12 == '12' and 12.0 .. '' == '12')
  assert(tostring(-1203 + 0.0) == "-1203")
end


x = '"ílo"\n\\'
assert(string.format('%q%s', x, x) == '"\\"ílo\\"\\\n\\\\""ílo"\n\\')
assert(string.format('%q', "\0") == [["\0"]])
assert(load(string.format('return %q', x))() == x)
x = "\0\1\0023\5\0009"
assert(load(string.format('return %q', x))() == x)
assert(string.format("\0%c\0%c%x\0", string.byte("\xe4"), string.byte("b"), 140) ==
              "\0\xe4\0b8c\0")
assert(string.format('') == "")
assert(string.format("%c",34)..string.format("%c",48)..string.format("%c",90)..string.format("%c",100) ==
       string.format("%c%c%c%c", 34, 48, 90, 100))
assert(string.format("%s\0 is not \0%s", 'not be', 'be') == 'not be\0 is not \0be')
assert(string.format("%%%d %010d", 10, 23) == "%10 0000000023")
assert(tonumber(string.format("%f", 10.3)) == 10.3)
x = string.format('"%-50s"', 'a')
assert(#x == 52)
assert(string.sub(x, 1, 4) == '"a  ')

assert(string.format("-%.20s.20s", string.rep("%", 2000)) ==
                     "-"..string.rep("%", 20)..".20s")
assert(string.format('"-%20s.20s"', string.rep("%", 2000)) ==
       string.format("%q", "-"..string.rep("%", 2000)..".20s"))

-- format x tostring
assert(string.format("%s %s", nil, true) == "nil true")
assert(string.format("%s %.4s", false, true) == "false true")
assert(string.format("%.3s %.3s", false, true) == "fal tru")
local m = setmetatable({}, {__tostring = function () return "hello" end})
assert(string.format("%s %.10s", m, m) == "hello hello")


assert(string.format("%x", 0.0) == "0")
assert(string.format("%02x", 0.0) == "00")
assert(string.format("%08X", 4294967295) == "FFFFFFFF")
assert(string.format("%+08d", 31501) == "+0031501")
assert(string.format("%+08d", -30927) == "-0030927")


do    -- longest number that can be formatted
  local i = 1
  local j = 10000
  while i + 1 < j do   -- binary search for maximum finite float
    local m = (i + j) // 2
    if 10^m < math.huge then i = m else j = m end
  end
  assert(10^i < math.huge and 10^j == math.huge)
  assert(string.len(string.format('%.99f', -(10^i))) > i)
end


-- testing large numbers for format
do   -- assume at least 32 bits
  local max, min = 0x7fffffff, -0x80000000    -- "large" for 32 bits
  assert(string.sub(string.format("%8x", -1), -8) == "ffffffff")
  assert(string.format("%x", max) == "7fffffff")
  assert(string.sub(string.format("%x", min), -8) == "80000000")
  assert(string.format("%d", max) ==  "2147483647")
  assert(string.format("%d", min) == "-2147483648")
  assert(string.format("%u", 0xffffffff) == "4294967295")
  assert(string.format("%o", 0xABCD) == "125715")

  max, min = 0x7fffffffffffffff, -0x8000000000000000
  if max > 2.0^53 then  -- only for 64 bits
    assert(string.format("%x", (2^52 | 0) - 1) == "fffffffffffff")
    assert(string.format("0x%8X", 0x8f000003) == "0x8F000003")
    assert(string.format("%d", 2^53) == "9007199254740992")
    assert(string.format("%i", -2^53) == "-9007199254740992")
    assert(string.format("%x", max) == "7fffffffffffffff")
    assert(string.format("%x", min) == "8000000000000000")
    assert(string.format("%d", max) ==  "9223372036854775807")
    assert(string.format("%d", min) == "-9223372036854775808")
    assert(string.format("%u", ~(-1 << 64)) == "18446744073709551615")
    assert(tostring(1234567890123) == '1234567890123')
  end
end


do print("testing 'format %a %A'")
  local function matchhexa (n)
    local s = string.format("%a", n)
    -- result matches ISO C requirements
    assert(string.find(s, "^%-?0x[1-9a-f]%.?[0-9a-f]*p[-+]?%d+$"))
    assert(tonumber(s) == n)  -- and has full precision
    s = string.format("%A", n)
    assert(string.find(s, "^%-?0X[1-9A-F]%.?[0-9A-F]*P[-+]?%d+$"))
    assert(tonumber(s) == n)
  end
  for _, n in ipairs{0.1, -0.1, 1/3, -1/3, 1e30, -1e30,
                     -45/247, 1, -1, 2, -2, 3e-20, -3e-20} do
    matchhexa(n)
  end

  assert(string.find(string.format("%A", 0.0), "^0X0%.?0?P%+?0$"))
  assert(string.find(string.format("%a", -0.0), "^%-0x0%.?0?p%+?0$"))

  if not _port then   -- test inf, -inf, NaN, and -0.0
    assert(string.find(string.format("%a", 1/0), "^inf"))
    assert(string.find(string.format("%A", -1/0), "^%-INF"))
    assert(string.find(string.format("%a", 0/0), "^%-?nan"))
    assert(string.find(string.format("%a", -0.0), "^%-0x0"))
  end
  
  if not pcall(string.format, "%.3a", 0) then
    (Message or print)("\n >>> modifiers for format '%a' not available <<<\n")
  else
    assert(string.find(string.format("%+.2A", 12), "^%+0X%x%.%x0P%+?%d$"))
    assert(string.find(string.format("%.4A", -12), "^%-0X%x%.%x000P%+?%d$"))
  end
end


-- errors in format

local function check (fmt, msg)
  checkerror(msg, string.format, fmt, 10)
end

local aux = string.rep('0', 600)
check("%100.3d", "too long")
check("%1"..aux..".3d", "too long")
check("%1.100d", "too long")
check("%10.1"..aux.."004d", "too long")
check("%t", "invalid option")
check("%"..aux.."d", "repeated flags")
check("%d %d", "no value")


assert(load("return 1\n--comment without ending EOL")() == 1)



if not _port then

  local locales = { "ptb", "ISO-8859-1", "pt_BR" }
  local function trylocale (w)
    for i = 1, #locales do
      if os.setlocale(locales[i], w) then return true end
    end
    return false
  end

  if not trylocale("collate")  then
    print("locale not supported")
  else
    assert("alo" < "álo" and "álo" < "amo")
  end

  if not trylocale("ctype") then
    print("locale not supported")
  else
    assert(string.gsub("áéíóú", "%a", "x") == "xxxxx")
    assert(string.gsub("áÁéÉ", "%l", "x") == "xÁxÉ")
    assert(string.gsub("áÁéÉ", "%u", "x") == "áxéx")
    assert(string.upper"áÁé{xuxu}ção" == "ÁÁÉ{XUXU}ÇÃO")
  end

  os.setlocale("C")
  assert(os.setlocale() == 'C')
  assert(os.setlocale(nil, "numeric") == 'C')

end

--]======]

print('OK')
