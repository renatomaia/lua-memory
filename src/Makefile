# == CHANGE THE SETTINGS BELOW TO SUIT YOUR ENVIRONMENT =======================

LUA_HOME= /usr/local
LUA_INC= $(LUA_HOME)/include
LUA_LIB= $(LUA_HOME)/lib
LUA_BIN= $(LUA_HOME)/bin

# Your platform. See PLATS for possible values.
PLAT= none

CC= gcc
CFLAGS= -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
LDFLAGS= -L$(LUA_LIB) $(MYLDFLAGS)
LIBS= $(MYLIBS)

AR= ar rcu
RANLIB= ranlib
RM= rm -f

MYCFLAGS=
MYLDFLAGS=
MYLIBS=

# == END OF USER SETTINGS -- NO NEED TO CHANGE ANYTHING BELOW THIS LINE =======

PLATS= linux solaris macosx

LIBNAME= luabuffer

OBJ=	lbuflib.o lstrlib.o lstrops.o lstraux.o
LIB=	lib$(LIBNAME).a
SO=	lib$(LIBNAME).so

default: $(PLAT)

all:	a so

o:	$(OBJ)

a:	$(LIB)

so:	$(SO)

# Static Libraies

$(LIB): $(OBJ)
	$(AR) $@ $^
	$(RANLIB) $@

# Dynamic Libraies

$(SO): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

clean:
	$(RM) $(OBJ) $(LIB) $(SO)

echo:
	@echo "CC = $(CC)"
	@echo "CFLAGS = $(CFLAGS)"
	@echo "AR = $(AR)"
	@echo "RANLIB = $(RANLIB)"
	@echo "RM = $(RM)"
	@echo "MYCFLAGS = $(MYCFLAGS)"
	@echo "MYLDFLAGS = $(MYLDFLAGS)"
	@echo "MYLIBS = $(MYLIBS)"

# Convenience targets for usual platforms
ALL= all

none:
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

linux:
	$(MAKE) $(ALL) LD="gcc" MYCFLAGS="-fpic $(MYCFLAGS)" \
	               MYLDFLAGS="-Wl,-E -O -shared $(MYLDFLAGS)"

solaris:
	$(MAKE) $(ALL) LD="gcc" MYCFLAGS="-fpic $(MYCFLAGS)" \
	               MYLDFLAGS="-O -shared $(MYLDFLAGS)"

macosx:
	$(MAKE) $(ALL) MYCFLAGS="-fno-common $(MYCFLAGS)" \
	               MYLDFLAGS="-bundle -undefined dynamic_lookup $(MYLDFLAGS)" \
	               LD='export MACOSX_DEPLOYMENT_TARGET="10.10"; gcc'

# (end of Makefile)
