local memory = require "memory"
local layout = require "memory.layout"

local function asserterr(msg, f, ...)
	local ok, res = pcall(f, ...)
	assert(ok == false)
	assert(string.find(res, msg, 1, true) ~= nil)
end

for _, bits in ipairs{3, 9} do
	asserterr("bigendian bits not supported",
		layout.newstruct, {{ key = "unsupported", bits = bits, endian = "big" }})
	asserterr("bigendian bits not supported",
		layout.newstruct, {{ key = "unsupported", bits = bits, endian = "native" }})
end

local function assertbits(m, bits)
	local index = 0
	local count = 0
	local value = 0
	for char in string.gmatch(bits, "[01]") do
		if char == "1" then
			value = value+(1<<count)
		end
		count = count+1
		if count == 8 then
			index = index+1
			assert(memory.get(m, index) == value)
			value = 0
			count = 0
		end
	end
	assert(memory.len(m) == index)
end

local function assertbytes(m, ...)
	local count = select("#", ...)
	for i = 1, count do
		assert(memory.get(m, i) == select(i, ...))
	end
	assert(memory.len(m) == count)
end

for _, endian in ipairs{"little", false} do
	endian = endian or nil
	local s = layout.newstruct{
		{ key = "one", bits = 1, endian = endian },
		{ key = "two", bits = 2, endian = endian },
		{ key = "three", bits = 3, endian = endian },
		{ key = "four", bits = 4, endian = endian },
		{ key = "eight", bits = 8, endian = endian },
		{ key = "six", bits = 6, endian = endian },
	}
	local p = layout.newpointer(s)

	asserterr("data too short", function () local _ = p.one end)
	asserterr("data too short", function () p.one = 0 end)

	local m = memory.create(3)
	layout.setpointer(p, m)

	memory.fill(m, 0xFF)
	assert(p.one == 1)     ; assertbits(m, "1 11 111 11|11 111111|11 111111")
	assert(p.two == 3)     ; assertbits(m, "1 11 111 11|11 111111|11 111111")
	assert(p.three == 7)   ; assertbits(m, "1 11 111 11|11 111111|11 111111")
	assert(p.four == 0xF)  ; assertbits(m, "1 11 111 11|11 111111|11 111111")
	assert(p.eight == 0xFF); assertbits(m, "1 11 111 11|11 111111|11 111111")
	assert(p.six == 0x3F)  ; assertbits(m, "1 11 111 11|11 111111|11 111111")
	p.one = 0              ; assertbits(m, "0 11 111 11|11 111111|11 111111")
	p.two = 0              ; assertbits(m, "0 00 111 11|11 111111|11 111111")
	p.three = 0            ; assertbits(m, "0 00 000 11|11 111111|11 111111")
	p.four = 0             ; assertbits(m, "0 00 000 00|00 111111|11 111111")
	p.eight = 0            ; assertbits(m, "0 00 000 00|00 000000|00 111111")
	p.six = 0              ; assertbits(m, "0 00 000 00|00 000000|00 000000")

	memory.fill(m, 0x55)
	assert(p.one == 1)     ; assertbits(m, "1 01 010 10|10 101010|10 101010")
	assert(p.two == 2)     ; assertbits(m, "1 01 010 10|10 101010|10 101010")
	assert(p.three == 2)   ; assertbits(m, "1 01 010 10|10 101010|10 101010")
	assert(p.four == 0x5)  ; assertbits(m, "1 01 010 10|10 101010|10 101010")
	assert(p.eight == 0x55); assertbits(m, "1 01 010 10|10 101010|10 101010")
	assert(p.six == 0x15)  ; assertbits(m, "1 01 010 10|10 101010|10 101010")
	p.one = 0              ; assertbits(m, "0 01 010 10|10 101010|10 101010")
	p.two = 1              ; assertbits(m, "0 10 010 10|10 101010|10 101010")
	p.three = 5            ; assertbits(m, "0 10 101 10|10 101010|10 101010")
	p.four = 0xA           ; assertbits(m, "0 10 101 01|01 101010|10 101010")
	p.eight = 0xAA         ; assertbits(m, "0 10 101 01|01 010101|01 101010")
	p.six = 0x2A           ; assertbits(m, "0 10 101 01|01 010101|01 010101")

	asserterr("value is too large", function () p.one = 2 end)
	asserterr("value is too large", function () p.two = 4 end)
	asserterr("value is too large", function () p.three = 8 end)
	asserterr("value is too large", function () p.four = 16 end)
	asserterr("value is too large", function () p.eight = 256 end)
	asserterr("value is too large", function () p.six = 64 end)
	assertbits(m, "0 10 101 01|01 010101|01 010101")
end

do
	local s = layout.newstruct{
		{ key = "one", bytes = 1 },
		{ key = "two", bytes = 2 },
		{ key = "three", bytes = 3 },
	}
	local p = layout.newpointer(s)
	local m = memory.create(6)
	layout.setpointer(p, m)

	memory.fill(m, 0xff)
	assert(p.one == 0xff)
	assert(p.two == 0xffff)
	assert(p.three == 0xffffff)
	p.one = 0x55       ; assertbytes(m, 0x55, 0xff, 0xff, 0xff, 0xff, 0xff);
	p.two = 0xaaaa     ; assertbytes(m, 0x55, 0xaa, 0xaa, 0xff, 0xff, 0xff);
	p.three = 0x333333 ; assertbytes(m, 0x55, 0xaa, 0xaa, 0x33, 0x33, 0x33);

	asserterr("value is too large", function () p.one = 1<<8 end)
	asserterr("value is too large", function () p.two = 1<<16 end)
	asserterr("value is too large", function () p.three = 1<<24 end)
end

do
	local endian = "little"
	local s = layout.newstruct{
		{ key = "one", bytes = 1, endian = endian },
		{ key = "two", bytes = 2, endian = endian },
		{ key = "three", bytes = 3, endian = endian },
	}
	local p = layout.newpointer(s)
	local m = memory.create(6)
	layout.setpointer(p, m)

	memory.fill(m, 0xff)
	assert(p.one == 0xff)
	assert(p.two == 0xffff)
	assert(p.three == 0xffffff)
	p.one = 0x21       ; assertbytes(m, 0x21, 0xff, 0xff, 0xff, 0xff, 0xff);
	p.two = 0x6543     ; assertbytes(m, 0x21, 0x43, 0x65, 0xff, 0xff, 0xff);
	p.three = 0xcba987 ; assertbytes(m, 0x21, 0x43, 0x65, 0x87, 0xa9, 0xcb);
end

do
	local endian = "big"
	local s = layout.newstruct{
		{ key = "one", bytes = 1, endian = endian },
		{ key = "two", bytes = 2, endian = endian },
		{ key = "three", bytes = 3, endian = endian },
	}
	local p = layout.newpointer(s)
	local m = memory.create(6)
	layout.setpointer(p, m)

	memory.fill(m, 0xff)
	assert(p.one == 0xff)
	assert(p.two == 0xffff)
	assert(p.three == 0xffffff)
	p.one = 0x21       ; assertbytes(m, 0x21, 0xff, 0xff, 0xff, 0xff, 0xff);
	p.two = 0x6543     ; assertbytes(m, 0x21, 0x65, 0x43, 0xff, 0xff, 0xff);
	p.three = 0xcba987 ; assertbytes(m, 0x21, 0x65, 0x43, 0xcb, 0xa9, 0x87);
end

do
	local s = layout.newstruct{
		{ key = "one", bytes = 1, endian = "native" },
		{ key = "two", bytes = 2, endian = "little" },
		{ key = "three", bytes = 3, endian = "big" },
	}
	local p = layout.newpointer(s)
	local m = memory.create(6)
	layout.setpointer(p, m)

	memory.fill(m, 0xff)
	assert(p.one == 0xff)
	assert(p.two == 0xffff)
	assert(p.three == 0xffffff)
	p.one = 0x21       ; assertbytes(m, 0x21, 0xff, 0xff, 0xff, 0xff, 0xff);
	p.two = 0x6543     ; assertbytes(m, 0x21, 0x43, 0x65, 0xff, 0xff, 0xff);
	p.three = 0xcba987 ; assertbytes(m, 0x21, 0x43, 0x65, 0xcb, 0xa9, 0x87);
end

do
	local s = layout.newstruct{
		{ key = "bits", bits = 3 },
		{ key = "bytes", bytes = 3, endian = "big" },
		{ bits = 3 },
		{ key = "morebits", bits = 3 },
	}
	local p = layout.newpointer(s)
	local m = memory.create(5)
	layout.setpointer(p, m)

	memory.fill(m, 0x55) assertbits(m, "101 01010|10101010|10101010|10101010|101 010 10")
	assert(p.bits == 0x5)
	assert(p.bytes == 0x555555)
	assert(p.morebits == 0x2)
	p.bits = 0x2      ; assertbits(m, "010 01010|10101010|10101010|10101010|101 010 10")
	p.bytes = 0xaaf00f; assertbits(m, "010 01010|01010101|00001111|11110000|101 010 10")
	p.morebits = 0x5  ; assertbits(m, "010 01010|01010101|00001111|11110000|101 101 10")
end
