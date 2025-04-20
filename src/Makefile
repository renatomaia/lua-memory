# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

# Your platform. See PLATS for possible values.
PLAT= guess

LUA_DIR= $(INSTALL_TOP)
LUA_INCDIR= $(LUA_DIR)/include

CC= gcc -std=c99
CFLAGS= -O2 -Wall -I. -I$(LUA_INCDIR) $(SYSCFLAGS)
LDFLAGS= $(SYSLDFLAGS)
LIBS= $(SYSLIBS)

AR= ar rcu
RANLIB= ranlib
RM= rm -f
UNAME= uname

SYSCFLAGS=
SYSLDFLAGS=
SYSLIBS=

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

PLATS= guess generic linux macosx mingw solaris

LIB_O= luamem.o
MOD_O= lmemlib.o
TST_O= ../test/ltestlib.o

LIB_T= libluamem.a
MOD_T= memory.so
TST_T= memory_test.so

ALL_O= $(MOD_O) $(LIB_O)
ALL_T= $(LIB_T) $(MOD_T)

default: $(PLAT)

all: $(ALL_T)

o: $(ALL_O)

lib: $(LIB_T)

mod: $(MOD_T)

$(LIB_T): $(LIB_O)
	$(AR) $@ $^
	$(RANLIB) $@

$(MOD_T): $(MOD_O) $(LIB_T)
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

$(TST_T): $(TST_O)
	$(CC) -o $@ $(LDFLAGS) $^

test: $(TST_T)
	$(LUA_DIR)/bin/lua -e 'assert(package.loadlib(assert(package.searchpath("memory", package.cpath)), "*"))' ../test/testall.lua

clean:
	$(RM) $(ALL_T) $(ALL_O) $(TST_T) $(TST_O)

depend:
	@$(CC) $(CFLAGS) -MM l*.c

echo:
	@echo "PLAT= $(PLAT)"
	@echo "CC= $(CC)"
	@echo "CFLAGS= $(CFLAGS)"
	@echo "LDFLAGS= $(LDFLAGS)"
	@echo "LIBS= $(LIBS)"
	@echo "AR= $(AR)"
	@echo "RANLIB= $(RANLIB)"
	@echo "RM= $(RM)"
	@echo "UNAME= $(UNAME)"

# Convenience targets for usual platforms
ALL= all

help:
	@echo "Do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

guess:
	@echo Guessing `$(UNAME)`
	@$(MAKE) `$(UNAME)`

generic: $(ALL)

Linux linux:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX -fPIC" \
	               SYSLDFLAGS="-shared" \

Darwin macos macosx:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" \
	               SYSLDFLAGS="-bundle -undefined dynamic_lookup" \
	               CC='export MACOSX_DEPLOYMENT_TARGET="10.8"; gcc' \

mingw:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_BUILD_AS_DLL -fPIC" \
	               SYSLDFLAGS="-shared" \
	               LIB_T="lua54mem21.dll" \
	               MOD_T="memory.dll" \
	               TST_T="memory_test.dll"

SunOS solaris:
	$(MAKE) $(ALL) SYSCFLAGS="-fPIC" SYSLDFLAGS="-O -shared"

# (end of Makefile)

# DO NOT DELETE

lmemlib.o: lmemlib.c luamem.h
luamem.o: luamem.c luamem.h
