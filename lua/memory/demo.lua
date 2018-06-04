local IPAddr = {
	[4] = layout.create{
		{ key = "route", value = "IPv4" },
		{ key = "iface", bits = 32 },
	},
	[6] = layout.create{
		{ key = "route", bits = 64 },
		{ key = "iface", bits = 64 },
	},
}

local IPHeader = {
	[4] = layout.create{
		{ key = "version" , bits = 4  },
		{ key = "ihl"     , bits = 4  },
		{ key = "tos"     , bits = 6  },
		{ key = "ecn"     , bits = 2  },
		{ key = "tot_len" , bits = 16 },
		{ key = "id"      , bits = 16 },
		{ key = "flags"   , bits = 3  },
		{ key = "frag_off", bits = 13 },
		{ key = "ttl"     , bits = 8  },
		{ key = "protocol", bits = 8  },
		{ key = "check"   , bits = 16 },
		{ key = "src"     , layout = IPAddr[4] },
		{ key = "dst"     , layout = IPAddr[4] },
	},
	[6] = layout.create{
		{ key = "version" , bits = 4  },
		{ key = "tc"      , bits = 8  },
		{ key = "fl"      , bits = 20 },
		{ key = "tot_len" , bits = 16 },
		{ key = "nh"      , bits = 8  },
		{ key = "hl"      , bits = 8  },
		{ key = "src"     , layout = IPAddr[6] },
		{ key = "dst"     , layout = IPAddr[6] },
	},
}

local uint2 = standard.uint(2)
local uint3 = standard.uint(3)
local uint4 = standard.uint(4)
local uint6 = standard.uint(6)
local uint8 = standard.uint8
local uint13 = standard.uint(13)
local uint16 = standard.uint16
local uint20 = standard.uint(20)
local uint64 = standard.uint64
local ipv4addr = standard.array{ length = 4, mapping = uint8 }
local ipv6addr = standard.tuple{
	{ key = "routing"  , mapping = uint64 },
	{ key = "interface", mapping = uint64 },
}
local IPHeader = standard.select{
	selector = { key = "version", mapping = uint4 },
	cases = {
		[4] = standard.tuple{
			{ key = "ihl"     , mapping = uint4  },
			{ key = "tos"     , mapping = uint6  },
			{ key = "ecn"     , mapping = uint2  },
			{ key = "tot_len" , mapping = uint16 },
			{ key = "id"      , mapping = uint16 },
			{ key = "flags"   , mapping = uint3  },
			{ key = "frag_off", mapping = uint13 },
			{ key = "ttl"     , mapping = uint8  },
			{ key = "protocol", mapping = uint8  },
			{ key = "check"   , mapping = uint16 },
			{ key = "src"     , mapping = ipv4addr },
			{ key = "dst"     , mapping = ipv4addr },
		},
		[6] = standard.tuple{
			{ key = "tc"     , mapping = uint8    },
			{ key = "fl"     , mapping = uint20   },
			{ key = "tot_len", mapping = uint16   },
			{ key = "nh"     , mapping = uint8    },
			{ key = "hl"     , mapping = uint8    },
			{ key = "src"    , mapping = ipv6addr },
			{ key = "dst"    , mapping = ipv6addr },
		},
	},
}

local IPv6ExtHeader = standard.tuple{
	{ key = "nh" , mapping = uint8 },
	{ key = "hdr", mapping = standard.embedded8 },
}
