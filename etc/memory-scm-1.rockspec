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
	"lua >= 5.4, < 5.5",
}
build = {
	type = "cmake",
	variables = {
		CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS = "ON",
		CMAKE_INSTALL_PREFIX = "$(PREFIX)",
		CMAKE_LIBRARY_PATH = "$(LUA_LIBDIR)",
		LUA_INCLUDE_DIR = "$(LUA_INCDIR)",
		LIBRARY_DESTINATION = "$(PREFIX)/library",
		MODULE_DESTINATION = "$(LIBDIR)",
	},
	copy_directories = {
		"demo",
		"doc",
		"test",
	},
}
