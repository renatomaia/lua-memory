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
PLATS= guess generic linux macosx solaris

# What to install.
TO_INC= lmemlib.h
TO_LIB= liblmemlib.so liblmemory.a
TO_CMOD= memory.so

# Lua version and release.
LUA_VER= 5.4

# Targets start here.
all: $(PLAT)

$(PLATS) help clean:
	@cd src && $(MAKE) $@

install: install_lib install_mod

install_lib:
	cd src && $(MKDIR) $(INSTALL_INC) $(INSTALL_LIB)
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INC)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIB)

install_mod:
	cd src && $(MKDIR) $(INSTALL_CMOD)
	cd src && $(INSTALL_DATA) $(TO_CMOD) $(INSTALL_CMOD)

uninstall: uninstall_lib uninstall_mod

uninstall_lib:
	cd src && cd $(INSTALL_INC) && $(RM) $(TO_INC)
	cd src && cd $(INSTALL_LIB) && $(RM) $(TO_LIB)

uninstall_mod:
	cd src && cd $(INSTALL_CMOD) && $(RM) $(TO_CMOD)

local:
	$(MAKE) install INSTALL_TOP=../install

# make may get confused with install/ if it does not support .PHONY.
dummy:

# Echo config parameters.
echo:
	@cd src && $(MAKE) -s echo
	@echo "PLAT= $(PLAT)"
	@echo "LUA_VER= $LUA_VER"
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
	@echo "prefix=$(INSTALL_TOP)"
	@echo "libdir=$(INSTALL_LIB)"
	@echo "includedir=$(INSTALL_INC)"

# Targets that do not create files (not all makes understand .PHONY).
.PHONY: all $(PLATS) help clean install install_lib install_mod \
        uninstall uninstall_lib uninstall_mod local dummy echo pc

# (end of Makefile)
