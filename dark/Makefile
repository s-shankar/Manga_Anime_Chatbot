LUADIR=/usr/local

LUABIN=${LUADIR}/bin
LUAINC=${LUADIR}/include
LUALIB=${LUADIR}/lib

CFLAGS =-std=c99 -W -Wall -O3
LIBS   =-llua -lm -ldl
INCDIR =-I${LUAINC}
LIBDIR =-L${LUALIB}

DESTDIR=
PREFIX =/usr/local

INSTALL= install -p
INSTALL_EXEC= $(INSTALL) -m 0755

dark: src/dark.c src/dark.inc
	@echo "CC: dark.c   --> dark"
	@$(CC) -DNDEBUG $(CFLAGS) $(INCDIR) $(LIBDIR) -o dark src/dark.c $(LIBS)

debug: src/dark.c src/dark.inc
	@echo "CC: dark.c   --> dark"
	@$(CC) -g $(CFLAGS) $(INCDIR) $(LIBDIR) -o dark src/dark.c $(LIBS)

src/dark.inc: src/dark.lua
	@echo "PP: dark.lua --> dark.inc"
	@echo "static const char dark_dat[] = {" > src/dark.inc
	@${LUABIN}/luac -o - src/dark.lua | od -v -t x1 |                              \
		sed 's/^[0-9]* *//;s/\([0-9a-f][0-9a-f]\)/0x\1,/g;s/  */ /g' \
		>> src/dark.inc
	@echo "};" >> src/dark.inc
	@echo "static const size_t dark_len = sizeof(dark_dat);" >> src/dark.inc

install: dark
	@echo "CP: dark   --> $(DESTDIR)$(PREFIX)/bin"
	@mkdir -p $(DESTDIR)$(PREFIX)/bin
	@$(INSTALL_EXEC) dark $(DESTDIR)$(PREFIX)/bin

clean:
	@echo "RM: dark"
	@rm -f dark
	@rm -f src/dark.inc

.PHONY: clean install
