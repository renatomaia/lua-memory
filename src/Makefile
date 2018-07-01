# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

LUA_HOME= /usr/local
LUA_INC= $(LUA_HOME)/include
LUA_LIB= $(LUA_HOME)/lib
LUA_BIN= $(LUA_HOME)/bin

# Your platform. See PLATS for possible values.
PLAT= none

CC= gcc -std=gnu99
CFLAGS= -O2 -Wall -I$(LUA_INC) $(SYSCFLAGS) $(MYCFLAGS)
LDFLAGS= $(SYSLDFLAGS) $(MYLDFLAGS)
LIBS= $(SYSLIBS) $(MYLIBS)

AR= ar rcu
RANLIB= ranlib
RM= rm -f

SYSCFLAGS=
SYSLDFLAGS=
SYSLIBS=

MYCFLAGS=
MYLDFLAGS=
MYLIBS=

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

PLATS= linux macosx

MEM_O=	lmemmod.o
API_O=	lmemlib.o

MEM_M=	memory.so
API_S=	libluamemlib.so
LIB_A=	libluamemory.a

ALL_O= $(MEM_O) $(API_O)
ALL_A= $(LIB_A)
ALL_S= $(API_S)
ALL_M= $(MEM_M)
ALL_T= $(ALL_A) $(ALL_S) $(ALL_M)

default: $(PLAT)

all:	$(ALL_T)

o:	$(ALL_O)

a:	$(ALL_A)

so:	$(ALL_S)

m:	$(ALL_M)

$(API_S): $(API_O)
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

$(MEM_M): $(MEM_O) $(API_S)
	$(CC) -o $@ $(LDFLAGS) $^ $(LIBS)

$(LIB_A): $(ALL_O)
	$(AR) $@ $^
	$(RANLIB) $@

clean:
	$(RM) $(ALL_T) $(ALL_O)

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

# Convenience targets for usual platforms
ALL= all

none:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

linux:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_LINUX -fpic" \
	               SYSLDFLAGS="-Wl,-E -O -shared"

macosx:
	$(MAKE) $(ALL) SYSCFLAGS="-DLUA_USE_MACOSX -fno-common" \
	               SYSLDFLAGS="-bundle -undefined dynamic_lookup" \
	               CC='export MACOSX_DEPLOYMENT_TARGET="10.10"; gcc'

# (end of Makefile)
