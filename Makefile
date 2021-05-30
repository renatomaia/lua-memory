# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

# Your platform. See PLATS for possible values.
PLAT= guess

# Where to install. The installation starts in the src directory,
# so take care if INSTALL_DIR is not an absolute path. See the local target.
# You may want to make INSTALL_CMODDIR consistent with LUA_ROOT, and LUA_CDIR
# in luaconf.h.
INSTALL_DIR= /usr/local
INSTALL_INCDIR= $(INSTALL_DIR)/include
INSTALL_LIBDIR= $(INSTALL_DIR)/lib
INSTALL_CMODDIR= $(INSTALL_DIR)/lib/lua/$(LUA_VER)

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
TO_INC= luamem.h
TO_LIB= libluamem.so libluamemory.a
TO_CMOD= memory.so

# Lua version and release.
LUA_VER= 5.4

# Targets start here.
all: $(PLAT)

lib:
	@cd src && $(MAKE) $(PLAT) ALL=lib

$(PLATS) help clean:
	@cd src && $(MAKE) $@

install: install_lib install_mod

install_lib:
	cd src && $(MKDIR) $(INSTALL_INCDIR) $(INSTALL_LIBDIR)
	cd src && $(INSTALL_DATA) $(TO_INC) $(INSTALL_INCDIR)
	cd src && $(INSTALL_DATA) $(TO_LIB) $(INSTALL_LIBDIR)

install_mod:
	cd src && $(MKDIR) $(INSTALL_CMODDIR)
	cd src && $(INSTALL_DATA) $(TO_CMOD) $(INSTALL_CMODDIR)

uninstall: uninstall_lib uninstall_mod

uninstall_lib:
	cd src && cd $(INSTALL_INCDIR) && $(RM) $(TO_INC)
	cd src && cd $(INSTALL_LIBDIR) && $(RM) $(TO_LIB)

uninstall_mod:
	cd src && cd $(INSTALL_CMODDIR) && $(RM) $(TO_CMOD)

local:
	$(MAKE) install INSTALL_DIR=../install

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
	@echo "INSTALL_DIR= $(INSTALL_DIR)"
	@echo "INSTALL_INCDIR= $(INSTALL_INCDIR)"
	@echo "INSTALL_LIBDIR= $(INSTALL_LIBDIR)"
	@echo "INSTALL_CMODDIR= $(INSTALL_CMODDIR)"
	@echo "INSTALL_DATA= $(INSTALL_DATA)"

# Targets that do not create files (not all makes understand .PHONY).
.PHONY: all $(PLATS) help clean install install_lib install_mod \
        uninstall uninstall_lib uninstall_mod local dummy echo pc

# (end of Makefile)
