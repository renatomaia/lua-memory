local memory = require "memory"
local layout = require "memory.layout"

local function asserterr(msg, f, ...)
	local ok, res = xpcall(f, debug.traceback, ...)
	assert(ok == false)
	assert(string.find(res, msg, 1, true) ~= nil, res)
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

do
	local s = layout.newstruct{
		{ key = "one", bits = 1 },
		{ key = "two", bits = 2 },
		{ key = "three", bits = 3 },
		{ key = "four", bits = 4 },
		{ key = "eight", bits = 8 },
		{ key = "six", bits = 6 },
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

	asserterr("unsigned overflow", function () p.one = 2 end)
	asserterr("unsigned overflow", function () p.two = 4 end)
	asserterr("unsigned overflow", function () p.three = 8 end)
	asserterr("unsigned overflow", function () p.four = 16 end)
	asserterr("unsigned overflow", function () p.eight = 256 end)
	asserterr("unsigned overflow", function () p.six = 64 end)
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

	asserterr("unsigned overflow", function () p.one = 1<<8 end)
	asserterr("unsigned overflow", function () p.two = 1<<16 end)
	asserterr("unsigned overflow", function () p.three = 1<<24 end)
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

do
	local s = layout.newstruct{
		{ key = "bit", bits = 1, type = "boolean" },
		{ key = "bits", bits = 4, type = "boolean" },
		{ key = "byte", bytes = 1, type = "boolean", endian = "native" },
		{ key = "little", bytes = 2, type = "boolean", endian = "little" },
		{ key = "big", bytes = 2, type = "boolean", endian = "big" },
	}
	local p = layout.newpointer(s)
	local m = memory.create(6)
	layout.setpointer(p, m)

	memory.fill(m, 0xff)
	assert(p.bit == true)
	assert(p.bits == true)
	assert(p.byte == true)
	assert(p.little == true)
	assert(p.big == true)
	memory.fill(m, 0)
	assert(p.bit == false)
	assert(p.bits == false)
	assert(p.byte == false)
	assert(p.little == false)
	assert(p.big == false)
	p.bit = true   ; assert(p.bit == true)   ; assertbytes(m, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00)
	p.bits = true  ; assert(p.bits == true)  ; assertbytes(m, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00)
	p.byte = true  ; assert(p.byte == true)  ; assertbytes(m, 0x03, 0x01, 0x00, 0x00, 0x00, 0x00)
	p.little = true; assert(p.little == true); assertbytes(m, 0x03, 0x01, 0x01, 0x00, 0x00, 0x00)
	p.big = true   ; assert(p.big == true)   ; assertbytes(m, 0x03, 0x01, 0x01, 0x00, 0x00, 0x01)
end

do
	for _, bits in ipairs{1, 2, 3, 4, 7, 9, 15, 17} do
		asserterr("unsupported type",
			layout.newstruct, {{ key = "unsupported", bits = bits, type = "string" }})
		for _, size in ipairs{8, 16, 32, 64} do
			asserterr("unsupported type",
				layout.newstruct, {
					{ bits = bits },
					{ key = "unsupported", bits = size, type = "string" },
				})
		end
	end

	local s = layout.newstruct{
		{ key = "one", bytes = 1, type = "string" },
		{ key = "two", bytes = 2, type = "string" },
		{ key = "eight", bytes = 8, type = "string" },
		{ key = "nine", bytes = 9, type = "string" },
	}
	local p = layout.newpointer(s)
	local m = memory.create(20)
	layout.setpointer(p, m)

	memory.fill(m, 0)
	assert(p.one == string.rep("\0", 1))
	assert(p.two == string.rep("\0", 2))
	assert(p.eight == string.rep("\0", 8))
	assert(p.nine == string.rep("\0", 9))

	local function assertmem(f, i, j)
		local v = string.rep("\x55", 1+j-i)
		p[f] = v
		assert(p[f] == v)
		for k = 1, i-1 do assert(memory.get(m, k) == 0) end
		for k = i, j do assert(memory.get(m, k) == 0x55) end
		for k = j+1, memory.len(m) do assert(memory.get(m, k) == 0) end
		memory.fill(m, 0)
	end
	assertmem("one", 1, 1)
	assertmem("two", 2, 3)
	assertmem("eight", 4, 11)
	assertmem("nine", 12, 20)
end

do
	local p = layout.newpointer(layout.newstruct{
		{ bits = 2 },
		{ key = "half", bits = 4, endian = "little" },
		{ key = "double", bytes = 2, endian = "big" },
		{ key = "nested", type = "struct",
			{ bits = 2 },
			{ key = "half", bits = 4, endian = "big" },
			{ key = "double", bytes = 2, endian = "little" },
			{ key = "single", bytes = 1 },
		},
		{ key = "single", bytes = 1 },
	})
	local m = memory.create(8)
	layout.setpointer(p, m)

	memory.set(m, 1, 0x10, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef)
	assert(p.half == 0x4)
	assert(p.double == 0x2345)
	assert(p.nested.half == 0x9)
	assert(p.nested.double == 0xab89)
	assert(p.nested.single == 0xcd)
	assert(p.single == 0xef)

	memory.fill(m, 0x55)
	p.half = 0xa            ; assertbytes(m, 0x69, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55)
	p.double = 0xaaf0       ; assertbytes(m, 0x69, 0xaa, 0xf0, 0x55, 0x55, 0x55, 0x55, 0x55)
	p.nested.half = 0xa     ; assertbytes(m, 0x69, 0xaa, 0xf0, 0x69, 0x55, 0x55, 0x55, 0x55)
	p.nested.double = 0xaaf0; assertbytes(m, 0x69, 0xaa, 0xf0, 0x69, 0xf0, 0xaa, 0x55, 0x55)
	p.nested.single = 0xaa  ; assertbytes(m, 0x69, 0xaa, 0xf0, 0x69, 0xf0, 0xaa, 0xaa, 0x55)
	p.single = 0xaa         ; assertbytes(m, 0x69, 0xaa, 0xf0, 0x69, 0xf0, 0xaa, 0xaa, 0xaa)

	local p2 = layout.newpointer(layout.newstruct{
		{ bytes = 1 },
		{ key = "nested", type = "struct", { bytes = 4 } },
	})
	local m2 = memory.create(6)
	layout.setpointer(p2, m2)
	p2.nested = p.nested    ; assertbytes(m2, 0x00, 0x69, 0xf0, 0xaa, 0xaa, 0x00)

	memory.fill(m2, 0xff)
	p.nested = p2.nested    ; assertbytes(m, 0x69, 0xaa, 0xf0, 0xff, 0xff, 0xff, 0xff, 0xaa)
end
