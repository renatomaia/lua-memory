# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

# Your platform. See PLATS for possible values.
PLAT= guess

# Where to install. The installation starts in the src directory,
# so take care if INSTALL_TOP is not an absolute path. See the local target.
# You may want to make INSTALL_CMOD consistent with LUA_ROOT, and LUA_CDIR
# in luaconf.h.
INSTALL_TOP= /usr/local
INSTALL_INC= $(INSTALL_TOP)/include
INSTALL_LIB= $(INSTALL_TOP)/lib
INSTALL_CMOD= $(INSTALL_TOP)/lib/lua/$(LUA_VER)

# How to install. If your install program does not support "-p", then
# you may have to run ranlib on the installed liblua.a.
INSTALL_DATA= install -p -m 0644
#
# If you don't have "install" you can use "cp" instead.
# INSTALL_DATA= cp -p

# Other utilities.
MKDIR= mkdir -p
RM= rm -f

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

# Convenience platforms targets.
PLATS= guess generic linux macosx mingw solaris

# What to install.
TO_INC= luamem.h
TO_LIB= libluamem.a
TO_CMOD= memory.so

# Lua version
LUA_VER= 5.4
# LuaMemory version and release.
V= 2.1
R= $V.0

# Targets start here.
all: $(PLAT)

lib:
	@cd src && $(MAKE) $(PLAT) ALL=lib

mod:
	@cd src && $(MAKE) $(PLAT) ALL=mod

$(PLATS) help clean test:
	@cd src && $(MAKE) $@

install: install_lib install_mod

install_lib: lib
	cd src && $(MKDIR) $(INSTALL_INC) $(INSTALL_LIB)
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)

install_mod: mod
	cd src && $(MKDIR) $(INSTALL_CMOD)
	cd src && $(INSTALL_DATA) $(TO_CMOD) $(INSTALL_CMOD)

uninstall: uninstall_lib uninstall_mod

uninstall_lib: lib
	cd src && cd $(INSTALL_INC) && $(RM) $(TO_INC)
	cd src && cd $(INSTALL_LIB) && $(RM) $(TO_LIB)

uninstall_mod: mod
	cd src && cd $(INSTALL_CMOD) && $(RM) $(TO_CMOD)

local:
	$(MAKE) install INSTALL_TOP=../install

# Echo config parameters.
echo:
	@cd src && $(MAKE) -s ALL=echo $(PLAT)
	@echo "PLAT= $(PLAT)"
	@echo "LUA_VER= $(LUA_VER)"
	@echo "V= $V"
	@echo "R= $R"
	@echo "TO_INC= $(TO_INC)"
	@echo "TO_LIB= $(TO_LIB)"
	@echo "TO_CMOD= $(TO_CMOD)"
	@echo "INSTALL_TOP= $(INSTALL_TOP)"
	@echo "INSTALL_INC= $(INSTALL_INC)"
	@echo "INSTALL_LIB= $(INSTALL_LIB)"
	@echo "INSTALL_CMOD= $(INSTALL_CMOD)"
	@echo "INSTALL_DATA= $(INSTALL_DATA)"

# Echo pkg-config data.
pc:
	@echo "version=$R"
	@echo "prefix=$(INSTALL_TOP)"
	@echo "libdir=$(INSTALL_LIB)"
	@echo "includedir=$(INSTALL_INC)"

# Targets that do not create files (not all makes understand .PHONY).
.PHONY: all $(PLATS) help clean test lib mod \
        install install_lib install_mod \
        uninstall uninstall_lib uninstall_mod \
        local echo pc

# (end of Makefile)
