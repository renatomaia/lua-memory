package="memory"
version="scm-1"
source = {
	url = "git://github.com/renatomaia/lua-memory",
}
description = {
	summary = "Manipulation of writable memory areas in Lua",
	detailed = [[
		Memory areas are much like Lua strings, but their contents can be
		modified in place and have an identity (selfness) independent from
		their contents.
	]],
	homepage = "https://github.com/renatomaia/lua-memory",
	license = "MIT/X11"
}
dependencies = {
	"lua >= 5.4",
}
external_dependencies = {
	LUAMEM = {
		header = "luamem.h",
		library = "luamem",
	},
}
build = {
	type = "builtin",
	modules = {
		memory = {
			sources = "src/lmemlib.c",
			libdirs = "$(LUAMEM_LIBDIR)",
			incdirs = "$(LUAMEM_INCDIR)",
			libraries = external_dependencies.LUAMEM.library,
		},
	},
}
