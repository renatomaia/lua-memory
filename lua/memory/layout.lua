local _G = require "_G"
local assert = _G.assert
local ipairs = _G.ipairs
local rawset = _G.rawset
local setmetatable = _G.setmetatable

local memory = require "memory"
local memnew = memory.create
local memcopy = memory.fill
local memget = memory.get
local mempack = memory.pack
local memunpack = memory.unpack
local memtostring = memory.tostring

local Pointer = {}

function Pointer:__index(key)
	local field = self.struct.fields[key]
	if field ~= nil then
		return field.read(self.parent)
	end
end

function Pointer:__newindex(key, value)
	local field = self.struct.fields[key]
	if field ~= nil then
		field.write(self.parent, value)
	end
end

function Pointer:__tostring()
	assert(self.struct.bitoff == 0 and self.struct.bits%8 == 0, 'unsupported')
	local startpos = self.parent.pos+self.struct.pos-1
	return memtostring(self.parent.buffer, startpos, startpos + self.struct.bytes-1)
end

local LuaIntBits = 64

local EndianFlag = {
	native = "",
	little = "<",
	big = ">",
}

local LittleEndian do
	local bytes = memnew(2)
	mempack(bytes, "I2", 1, 1)
	LittleEndian = {
		[">"] = false,
		["<"] = true,
		[""] = memget(bytes, 1) == 1,
	}
end

local function calcsizes(field, byteidx, bitoff)
	local bitpart
	local bytes
	local bits = field.bits
	if bits == nil then
		bytes = field.bytes
		if bitoff > 0 then -- byte align
			byteidx = byteidx+1
			bitoff = 0
		end
		bits = bytes*8
		bitpart = 0
	else
		local bitused = bitoff+bits
		bitpart = bitused%8
		bytes = bitused//8
	end
	local spec = {
		pos = byteidx,
		bitoff = bitoff,
		bits = bits,
		bytes = bytes,
	}
	return spec, byteidx, bitoff, bytes, bits, bitpart
end

local layout = {}

function layout.string(field, ...)
	local spec, byteidx, bitoff, bytes, bits, bitpart = calcsizes(field, ...)

	assert(bitoff == 0 and bitpart == 0, "unsupported type")
	local format = "c"..bytes
	function spec.read(self)
		return memunpack(self.buffer, format, byteidx+self.pos-1)
	end
	function spec.write(self, value)
		mempack(self.buffer, format, byteidx+self.pos-1, value)
	end

	return spec, byteidx+bytes, bitoff
end

function layout.number(field, ...)
	local spec, byteidx, bitoff, bytes, bits, bitpart = calcsizes(field, ...)
	assert(bits <= LuaIntBits, "size is too big")

	local endian = field.endian
	if endian == nil then endian = "native" end
	endian = assert(EndianFlag[endian], "illegal endianess")

	if bitoff == 0 and bitpart == 0 then
		local format = endian.."I"..bytes
		function spec.read(self)
			return memunpack(self.buffer, format, byteidx+self.pos-1)
		end
		function spec.write(self, value)
			if not mempack(self.buffer, format, byteidx+self.pos-1, value) then
				error("out of bounds")
			end
		end
	else
		local mask = (~0>>(LuaIntBits-bits))
		local shift = LittleEndian[endian] and bitoff or (8-bitpart)%8
		if bitpart > 0 then
			spec.bytes = bytes+1
		end
		local format = endian.."I"..spec.bytes
		function spec.read(self)
			return (memunpack(self.buffer, format, byteidx+self.pos-1)>>shift)&mask
		end
		function spec.write(self, value)
			assert(value <= mask, "unsigned overflow")
			local buffer = self.buffer
			local pos = byteidx+self.pos-1
			local current = memunpack(buffer, format, pos)
			value = (current&~(mask<<shift))|(value<<shift)
			mempack(buffer, format, pos, value)
		end
	end

	return spec, byteidx+bytes, bitpart
end

function layout.boolean(...)
	local spec, byteidx, bitoff = layout.number(...)
	local read = spec.read
	function spec.read(...)
		return read(...) ~= 0
	end
	local write = spec.write
	function spec.write(self, value, ...)
		return write(self, value and 1 or 0, ...)
	end
	return spec, byteidx, bitoff
end

local function layoutstruct(fields, byteidx, bitoff)
	assert(type(fields) == "table" and #fields > 0, "invalid type")
	local spec = {
		pos = byteidx,
		bitoff = bitoff,
		bits = 0,
		bytes = 0,
	}

	local specs = {}
	for _, field in ipairs(fields) do
		local key = field.key
		local type = field.type
		if type == nil then type = "number" end
		local build = assert(layout[type], "unsupported type")
		field, byteidx, bitoff = build(field, byteidx, bitoff)

		spec.bytes = byteidx-spec.pos
		spec.bits = 8*(spec.bytes)+bitoff-spec.bitoff

		if key ~= nil then
			specs[key] = field
		end
	end
	spec.fields = specs
	return spec, byteidx, bitoff
end

function layout.struct(field, ...)
	local spec, byteidx, bitoff = layoutstruct(field, ...)
	function spec.read(self)
		local pointer = self[spec]
		if pointer == nil then
			pointer = setmetatable({ struct = spec, parent = self }, Pointer)
			self[spec] = pointer
		end
		return pointer
	end
	function spec.write(self, value, ...)
		if getmetatable(value) == Pointer then
			local src, dst = value.struct, spec
			assert(src.bitoff == 0 and src.bits%8 == 0
			   and dst.bitoff == 0 and dst.bits%8 == 0, "unsupported")
			assert(dst.bytes == src.bytes, "size mismatch")
			memcopy(self.parent.buffer, value.parent.buffer,
				dst.pos, dst.pos+dst.bytes-1, src.pos)
		else
			error("unsupported")
		end
	end
	return spec, byteidx, bitoff
end


local module = {}

function module.newstruct(fields)
	return layoutstruct(fields, 1, 0)
end

local empty = memnew(0)
function module.newpointer(struct)
	local pointer = setmetatable({
		struct = struct,
		buffer = empty,
		pos = 1,
	}, Pointer)
	rawset(pointer, "parent", pointer)
	return pointer
end

function module.setpointer(pointer, buffer, pos)
	rawset(pointer, "buffer", buffer)
	rawset(pointer, "pos", pos or 1)
end

return module
