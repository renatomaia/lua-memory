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
	local field = self.struct.fields[key]
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
				if field.type == "boolean" then
					value = value ~= 0
				end
			else
				-- TODO
			end
		end
		return value
	end
end

function Pointer:__newindex(key, value)
	local field = self.struct.fields[key]
	if field ~= nil then
		if field.value ~= nil then
			assert(field.value == value, "invalid value")
		else
			local format = field.format
			if format ~= nil then
				if field.type == "boolean" then
					value = value and 1 or 0
				end
				local current = unpackmem(self.buffer, field.format, field.pos)
				local shift, mask = field.shift, field.mask
				assert(value <= mask, "value is too large")
				current = (current&~(mask<<shift))|(value<<shift)
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

	local endian = field.endian
	if bitoff > 0 or bitpart > 0 then
		assert(endian == nil or endian == "little", "bigendian bits not supported")
		endian = "<"
	elseif endian == "little" then
		endian = "<"
	elseif endian == "big" then
		endian = ">"
	else
		assert(endian == nil or endian == "native", "illegal endianess")
		endian = "="
	end

	field = {
		pos = byteidx,
		bitoff = bitoff,
		bits = bits,
		mask = (~0>>(LuaIntBits-bits)),
		shift = bitoff,
		value = field.value,
		type = field.type or "number",
	}

	byteidx = byteidx+bytes
	if bitpart > 0 then
		bytes = bytes+1
		bitoff = bitpart
	end

	field.bytes = bytes
	field.format = endian.."I"..bytes

	return field, byteidx, bitoff
end

function layoutstruct(spec, byteidx, bitoff) -- local defined above
	local struct = {
		pos = byteidx,
		bitoff = bitoff,
		bits = 0,
		bytes = 0,
	}
	local fields = {}
	for _, field in ipairs(spec) do
		local key = field.key
		field, byteidx, bitoff = layoutfield(field, byteidx, bitoff)

		struct.bytes = field.pos-1+field.bytes
		struct.bits = 8*(byteidx-1)+bitoff

		if key ~= nil then
			assert(field.bits <= LuaIntBits, "value is too big")
			assert(field.bytes <= 8)
			fields[key] = field
		end
	end
	struct.fields = fields
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
