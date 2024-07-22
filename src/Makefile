# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

LUA_DIR= /usr/local
LUA_INCDIR= $(LUA_DIR)/include

# Your platform. See PLATS for possible values.
PLAT= guess

CC= gcc -std=gnu99
CFLAGS= -O2 -Wall -I. -I$(LUA_INCDIR) $(SYSCFLAGS) $(MYCFLAGS)
LDFLAGS= $(SYSLDFLAGS) $(MYLDFLAGS)
LIBS= $(SYSLIBS) $(MYLIBS)

AR= ar rcu
RANLIB= ranlib
RM= rm -f
UNAME= uname

SYSCFLAGS=
SYSLDFLAGS=
SYSLIBS=

MYCFLAGS=
MYLDFLAGS=
MYLIBS=

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

PLATS= guess generic linux macosx solaris

LIB_O= luamem.o
MEM_O= lmemlib.o
TST_O= ../test/ltestlib.o

LIB_A= libluamem.a
LIB_S= libluamem.so
MEM_M= memory.so
TST_M= memory_test.so

ALL_O= $(MEM_O) $(LIB_O)
ALL_A= $(LIB_A)
ALL_S= $(LIB_S)
ALL_M= $(MEM_M)
ALL_T= $(ALL_A) $(ALL_S) $(ALL_M)

default: $(PLAT)

all: $(ALL_T)

o: $(ALL_O)

a: $(ALL_A)

so: $(ALL_S)

lib: a so

mod: $(ALL_M)

$(LIB_A): $(ALL_O)
	$(AR) $@ $^
	$(RANLIB) $@

$(LIB_S): $(LIB_O)
	$(LD) -o $@ $(LDFLAGS) $^ $(LIBS)

$(MEM_M): $(MEM_O) $(LIB_S)
	$(LD) -o $@ $(LDFLAGS) $^ $(LIBS)

$(TST_M): $(TST_O) $(LIB_S)
	$(LD) -o $@ $(LDFLAGS) $^ $(LIBS)

test: $(TST_M) $(MEM_M)
	LD_LIBRARY_PATH=. $(LUA_DIR)/bin/lua -e 'package.cpath="./?.so"' ../test/testall.lua

clean:
	$(RM) $(ALL_T) $(ALL_O) $(TST_M) $(TST_O)

depend:
	@$(CC) $(CFLAGS) -MM l*.c

echo:
	@echo "PLAT= $(PLAT)"
	@echo "CC= $(CC)"
	@echo "CFLAGS= $(CFLAGS)"
	@echo "LDFLAGS= $(SYSLDFLAGS)"
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
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX -fpic" \
	               SYSLDFLAGS="-shared"

Darwin macos macosx:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" \
	               SYSLDFLAGS="-bundle -undefined dynamic_lookup" \
	               CC='export MACOSX_DEPLOYMENT_TARGET="10.10"; gcc' \
	               LD='export MACOSX_DEPLOYMENT_TARGET="10.10"; gcc'

SunOS solaris:
	$(MAKE) $(ALL) SYSCFLAGS="-fpic" SYSLDFLAGS="-O -shared"

# (end of Makefile)
