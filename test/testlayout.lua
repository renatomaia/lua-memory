local memory = require "memory"
local layout = require "memory.layout"

local function asserterr(msg, f, ...)
	local ok, res = xpcall(f, debug.traceback, ...)
	assert(ok == false)
	assert(string.find(res, msg, 1, true) ~= nil, res)
end

local function assertbytes(m, ...)
	local count = select("#", ...)
	for i = 1, count do
		assert(memory.get(m, i) == select(i, ...),
			string.format("%d: %02x ~= %02x", i, memory.get(m, i), select(i, ...)))
	end
	assert(memory.len(m) == count)
end

local native = string.unpack("B", string.pack("I2", 1)) == 0 and "big" or "little"
local function testfields(spec)
	for _, endian in ipairs{"big", "little", "native", false} do
		for _, field in ipairs(spec.struct) do
			field.endian = endian or nil
		end
		local p = layout.newpointer(layout.newstruct(spec.struct))
		for i, field in ipairs(spec.struct) do
			if field.key ~= nil then
				asserterr("out of bounds", function () local _ = p[field.key] end)
				asserterr("out of bounds", function () p[field.key] = 0 end)
			end
		end
		local m = memory.create(spec.length)
		layout.setpointer(p, m)
		for _, field in ipairs(spec.struct) do
			p[field.key] = spec.values[field.key]
		end
		assertbytes(m, table.unpack(spec[endian] or spec[native]))
		for _, field in ipairs(spec.struct) do
			if field.key ~= nil then
				asserterr("unsigned overflow", function ()
					p[field.key] = 1<<(field.bits or field.bytes*8)
				end)
			end
			assert(p[field.key] == spec.values[field.key])
		end
		assertbytes(m, table.unpack(spec[endian] or spec[native]))
	end
end

testfields{
	length = 8,
	struct = {
		{ key = "a", bits = 1 },
		{ key = "b", bits = 2 },
		{ key = "c", bits = 3 },
		{ key = "d", bits = 4 },
		{ key = "e", bits = 5 },
		{ key = "f", bits = 6 },
		{ key = "g", bits = 7 },
		{ key = "h", bits = 8 },
		{ key = "i", bits = 12 },
		{ key = "j", bits = 6 },
		{ key = "k", bits = 1 },
		{ key = "l", bits = 2 },
		{ key = "m", bits = 3 },
		{ key = "n", bits = 4 },
	},
	values = {
		a = 0x01,  --              1
		b = 0x01,  --             01
		c = 0x03,  --            011
		d = 0x0b,  --           1011
		e = 0x13,  --         1 0011
		f = 0x25,  --        10 0101
		g = 0x45,  --       100 0101
		h = 0xc9,  --      1100 1001
		i = 0x821, -- 1000 0010 0001
		j = 0x25,  --        10 0101
		k = 0x00,  --              0
		l = 0x02,  --             10
		m = 0x04,  --            100
		n = 0x0d,  --           1101
	},
	big    = {
		      -- abbc ccdd
		0xae, -- 1010 1110
		      -- ddee eeef
		0xe7, -- 1110 0111
		      -- ffff fggg
		0x2c, -- 0010 1100
		      -- gggg hhhh
		0x5c, -- 0101 1100
		      -- hhhh iiii
		0x98, -- 1001 1000
		      -- iiii iiii
		0x21, -- 0010 0001
		      -- jjjj jjkl
		0x95, -- 1001 0101
		      -- lmmm nnnn
		0x4d, -- 0100 1101
	},
	little = {
		      -- ddcc cbba
		0xdb, -- 1101 1011
		      -- feee eedd
		0xce, -- 1100 1110
		      -- gggf ffff
		0xb2, -- 1011 0010
		      -- hhhh gggg
		0x98, -- 1001 1000
		      -- iiii hhhh
		0x1c, -- 0001 1100
		      -- iiii iiii
		0x82, -- 1000 0010
		      -- lkjj jjjj
		0x25, -- 0010 0101
		      -- nnnn mmml
		0xd9, -- 1101 1001
	},
}

testfields{
	length = 8,
	struct = {
		{ key = "a", bits = 9 },
		{ key = "b", bits = 17 },
		{ key = "c", bits = 25 },
		{ key = "d", bits = 13 },
	},
	values = {
		a =     0x002, --                     0 0000 0010
		b =   0x08d15, --           0 1000 1101 0001 0101
		c = 0x13c4d5e, -- 1 0011 1100 0100 1101 0101 1110
		d =    0x0def, --                0 1101 1110 1111
	},
	big    = {
		      -- aaaa aaaa
		0x01, -- 0000 0001
		      -- abbb bbbb
		0x23, -- 0010 0011
		      -- bbbb bbbb
		0x45, -- 0100 0101
		      -- bbcc cccc
		0x67, -- 0110 0111
		      -- cccc cccc
		0x89, -- 1000 1001
		      -- cccc cccc
		0xab, -- 1010 1011
		      -- cccd dddd
		0xcd, -- 1100 1101
		      -- dddd dddd
		0xef, -- 1110 1111
	},
	little = {
		      -- aaaa aaaa
		0x02, -- 0000 0010
		      -- bbbb bbba
		0x2a, -- 0010 1010
		      -- bbbb bbbb
		0x1a, -- 0001 1010
		      -- cccc ccbb
		0x79, -- 0111 1001
		      -- cccc cccc
		0x35, -- 0011 0101
		      -- cccc cccc
		0xf1, -- 1111 0001
		      -- dddd dccc
		0x7c, -- 0111 1100
		      -- dddd dddd
		0x6f, -- 0110 1111
	},
}

testfields{
	length = 6,
	struct = {
		{ key = "one", bytes = 1 },
		{ key = "two", bytes = 2 },
		{ key = "three", bytes = 3 },
	},
	values = {
		one = 0x12,
		two = 0x3456,
		three = 0x789abc,
	},
	big    = { 0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc },
	little = { 0x12, 0x56, 0x34, 0xbc, 0x9a, 0x78 },
}

testfields{
	length = 5,
	struct = {
		{ key = "bits", bits = 3 },
		{ key = "bytes", bytes = 3 },
		{ bits = 3 },
		{ key = "morebits", bits = 3 },
	},
	values = {
		bits = 0x2,
		bytes = 0xaaf00f,
		morebits = 0x5,
	},
	big    = { 0x40, 0xaa, 0xf0, 0x0f, 0x14 },
	little = { 0x02, 0x0f, 0xf0, 0xaa, 0x28 },
}

do
	local p = layout.newpointer(layout.newstruct{
		{ key = "bigbytes", bytes = 2, endian = "big" },
		{ key = "littlebytes", bytes = 2, endian = "little" },
		{ key = "fewbigbits", bits = 3, endian = "big" },
		{ key = "manybigbits", bits = 13, endian = "big" },
		{ key = "fewlittlebits", bits = 3, endian = "little" },
		{ key = "manylittlebits", bits = 13, endian = "little" },
	})
	local m = memory.create(8)
	layout.setpointer(p, m)

	memory.set(m, 1, 0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef)
	assert(p.bigbytes == 0x0123)
	assert(p.littlebytes == 0x6745)
	assert(p.fewbigbits == 0x4)        --  100
	assert(p.manybigbits == 0x9ab)     --     0 1001  1010 1011
	assert(p.fewlittlebits == 0x5)     --       [101]
	assert(p.manylittlebits == 0x1df9) --..1100 1]   [1110 1111..
	p.bigbytes = 0xfedc     ; assertbytes(m, 0xfe, 0xdc, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef)
	p.littlebytes = 0x98ba  ; assertbytes(m, 0xfe, 0xdc, 0xba, 0x98, 0x89, 0xab, 0xcd, 0xef)
	-- 100|0 1001  1010 1011 --> 011|0 1001  1010 1011
	p.fewbigbits = 0x3      ; assertbytes(m, 0xfe, 0xdc, 0xba, 0x98, 0x69, 0xab, 0xcd, 0xef)
	-- 011|0 1001  1010 1011 --> 011|1 0110  0101 0100
	p.manybigbits = 0x1654  ; assertbytes(m, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0xcd, 0xef)
	--..1100 1][101]  [1110 1111.. -->  ..1100 1][010]  [1110 1111..
	p.fewlittlebits = 0x2   ; assertbytes(m, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0xca, 0xef)
	--..1100 1][010]  [1110 1111.. -->  ..0011 0][010]  [0001 0000..
	p.manylittlebits = 0x206; assertbytes(m, 0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10)
end

do
	local p = layout.newpointer(layout.newstruct{
		{ key = "bit", bits = 1, type = "boolean", endian = "little" },
		{ key = "bits", bits = 4, type = "boolean", endian = "little" },
		{ key = "byte", bytes = 1, type = "boolean", endian = "native" },
		{ key = "little", bytes = 2, type = "boolean", endian = "little" },
		{ key = "big", bytes = 2, type = "boolean", endian = "big" },
	})
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

	local p = layout.newpointer(layout.newstruct{
		{ key = "one", bytes = 1, type = "string" },
		{ key = "two", bytes = 2, type = "string" },
		{ key = "eight", bytes = 8, type = "string" },
		{ key = "nine", bytes = 9, type = "string" },
	})
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

	for _, size in ipairs{1,2,3,5,6} do
		local p3 = layout.newpointer(layout.newstruct{
			{ key = "nested", type = "struct", { bytes = size } },
		})
		local m3 = memory.create(size)
		layout.setpointer(p3, m3)
		asserterr("size mismatch", function () p3.nested = p.nested end)
		asserterr("size mismatch", function () p.nested = p3.nested end)
	end
end

do
	local p = layout.newpointer(layout.newstruct{
		{ key = "half", bits = 4, endian = "big" },
		{ key = "nested", type = "struct",
			{ key = "half", bits = 4, endian = "big" },
			{ key = "many", bits = 14, endian = "big" },
			{ key = "one", bits = 1, endian = "big" },
		},
		{ key = "one", bits = 1, endian = "big" },
	})
	local m = memory.create(3)
	layout.setpointer(p, m)

	memory.set(m, 1, 0x12, 0x34, 0x56)
	assert(p.half == 0x1)
	assert(p.nested.half == 0x2)
	assert(p.nested.many == 0x3454>>2)
	assert(p.nested.one == 0x1)
	assert(p.one == 0x0)

	memory.fill(m, 0x55)
	p.half = 0xa              ; assertbytes(m, 0xa5, 0x55, 0x55)
	p.nested.half = 0xb       ; assertbytes(m, 0xab, 0x55, 0x55)
	p.nested.many = 0xcdec>>2 ; assertbytes(m, 0xab, 0xcd, 0xed)
	p.nested.one = 0x1        ; assertbytes(m, 0xab, 0xcd, 0xef)
	p.one = 0x1               ; assertbytes(m, 0xab, 0xcd, 0xef)

	local p2 = layout.newpointer(layout.newstruct{
		{ bits = 7 },
		{ key = "nested", type = "struct", { bits = 9 } },
	})
	local m2 = memory.create(2)
	layout.setpointer(p2, m2)
	asserterr("unsupported", function () p2.nested = p.nested end)
	asserterr("unsupported", function () p.nested = p2.nested end)
end

do
	local p = layout.newpointer(layout.newstruct{
		{ key = "one", bytes = 1 },
		{ key = "other", bytes = 1 },
	})
	local m = memory.create(6)
	memory.set(m, 1, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05)
	layout.setpointer(p, m, 3)
	assert(p.one == 2)
	assert(p.other == 3)
	p.one = 252
	p.other = 253
	layout.setpointer(p, m, 5)
	assert(p.one == 4)
	assert(p.other == 5)
	p.one = 254
	p.other = 255
	assertbytes(m, 0x00, 0x01, 0xfc, 0xfd, 0xfe, 0xff)
end

print("Success!")
