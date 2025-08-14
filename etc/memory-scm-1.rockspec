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
	"lua >= 5.4, < 5.6",
}
build = {
	type = "cmake",
	variables = {
		CMAKE_INSTALL_PREFIX = "$(PREFIX)",
		CMAKE_INSTALL_LIBDIR = "$(PREFIX)/library",
		LUA_MODULE_DIR = "$(LIBDIR)",
		LUA_INCLUDE_DIR = "$(LUA_INCDIR)",
		LUA_LIBRARY_DIR = "$(LUA_LIBDIR)",
		LUA_LIBRARY_FILE = "$(LUA_LIBDIR_FILE)",
	},
	copy_directories = {
		"demo",
		"doc",
		"test",
	},
}
