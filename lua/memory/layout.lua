local _G = require "_G"
local assert = _G.assert
local ipairs = _G.ipairs
local rawset = _G.rawset
local setmetatable = _G.setmetatable

local memory = require "memory"
local newmem = memory.create
local packmem = memory.pack
local unpackmem = memory.unpack

local Pointer = {}

function Pointer:__index(key)
	local field = self.struct[key]
	if field ~= nil then
		local value = field.value
		if value == nil then
			local format = field.format
			if format ~= nil then
				value = unpackmem(self.buffer, field.format, field.pos)
				local shift, mask = field.shift, field.mask
				if shift > 0 then
					value = value>>shift
				end
				if mask ~= ~0 then
					value = value&mask
				end
			else
				-- TODO
			end
		end
		return value
	end
end

function Pointer:__newindex(key, value)
	local field = self.struct[key]
	if field ~= nil then
		if field.value ~= nil then
			assert(field.value == value, "invalid value")
		else
			local format = field.format
			if format ~= nil then
				local current = unpackmem(self.buffer, field.format, field.pos)
				local shift, mask = field.shift, field.mask
				assert(value <= mask, "value is too large")

io.write(key," = ",string.format("%02x", current)," -> ")

				current = (current&~(mask<<shift))|(value<<shift)

print(string.format("%02x", current))

				packmem(self.buffer, field.format, field.pos, current)
			else
				-- TODO
			end
		end
	end
end

local LuaIntBits = 64

local layoutstruct -- forward declaration

local function layoutfield(field, byteidx, bitoff)
	local bits = field.bits
	if bits == nil then
		local bytes = field.bytes
		if bytes == nil then
			local struct = field.struct
			if struct ~= nil then
				return layoutstruct(struct, byteidx, bitoff)
			end
			bits = 0
		else
			if bitoff > 0 then -- byte align
				byteidx = byteidx+1
				bitoff = 0
			end
			bits = bytes*8
		end
	end

	local bitused = bitoff+bits
	local bitpart = bitused%8
	local bytes = bitused//8

	field = {
		pos = byteidx,
		bitoff = bitoff,
		bits = bits,
		mask = (~0>>(LuaIntBits-bits)),
		shift = bitoff,
		value = field.value,
	}

	byteidx = byteidx+bytes
	if bitpart > 0 then
		bytes = bytes+1
		bitoff = bitpart
	end

	field.bytes = bytes
	field.format = "I"..bytes

	return field, byteidx, bitoff
end

function layoutstruct(fields, byteidx, bitoff) -- local defined above
	local struct = {
		pos = byteidx,
		bitoff = bitoff,
		bits = 0,
		bytes = 0,
	}
	for _, field in ipairs(fields) do
		local key = field.key
		field, byteidx, bitoff = layoutfield(field, byteidx, bitoff)

		struct.bytes = field.pos-1+field.bytes
		struct.bits = 8*(byteidx-1)+bitoff

		if key ~= nil then
			assert(field.bits <= LuaIntBits, "value is too big")
			assert(field.bytes <= 8)
			struct[key] = field
		end
	end
	return struct, byteidx, bitoff
end


local module = {}

function module.newstruct(fields)
	return layoutstruct(fields, 1, 0)
end

local empty = newmem(0)
function module.newpointer(struct)
	return setmetatable({
		struct = struct,
		buffer = empty,
	}, Pointer)
end

function module.setpointer(pointer, buffer, pos)
	rawset(pointer, "buffer", buffer)
	rawset(pointer, "pos", pos)
end

return module
