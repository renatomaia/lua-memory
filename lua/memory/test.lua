local memory = require "memory"
local layout = require "memory.layout"

local s = layout.newstruct{
	{ key = "onebit", bits = 1 },
	{ key = "twobits", bits = 2 },
	{ key = "threebits", bits = 3 },
	{ key = "fourbits", bits = 4 },
	{ key = "eightbits", bits = 8 },
	{ key = "onebyte", bytes = 1 },
}
local p = layout.newpointer(s)

local m = memory.create(s.bytes)
memory.fill(m, 0x55)
layout.setpointer(p, m)

require("loop.debug.Viewer"):write(s); print()

assert(p.onebit == 1, p.onebit)          --          1
assert(p.twobits == 2, p.twobits)        --        10
assert(p.threebits == 2, p.threebits)    --     010
assert(p.fourbits == 5, p.fourbits)      -- 0101
assert(p.eightbits == 0x55, p.eightbits) --   01010101
assert(p.onebyte == 0x55, p.onebyte)     --   01010101

p.onebit = 0
p.twobits = 3
p.threebits = 0
p.fourbits = 0xF
p.eightbits = 0
p.onebyte = 0xFF

for i = 1, #m do
	io.write(string.format("%02x", memory.get(m, i)))
end
print()

assert(p.onebit == 0)
assert(p.twobits == 3)
assert(p.threebits == 0)
assert(p.fourbits == 0xF)
assert(p.eightbits == 0)
assert(p.onebyte == 0xFF)

assert(tostring(m) == string.char(0xC6, 0x03, 0x54, 0xFF))
-- 0101 0100  0000 0011  1100 0110

--[[
c60354ff
47d401ff

--]]