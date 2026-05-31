# Build the 32-bit rUGP plugin. Requires an i686-w64-mingw32 GCC toolchain.
#   Linux:   sudo apt-get install gcc-mingw-w64-i686 binutils-mingw-w64-i686
#   Windows: scoop install mingw-mstorsjo-llvm-msvcrt   (or use build.ps1)
CC      ?= i686-w64-mingw32-gcc
CFLAGS  ?= -O2 -s
TARGET   = KasekiResetState.rpo

$(TARGET): src/kaseki_reset.c src/kaseki_reset.def
	$(CC) -shared $(CFLAGS) -o $@ src/kaseki_reset.c src/kaseki_reset.def -lkernel32

loader: tools/loader.c
	$(CC) -municode $(CFLAGS) -o tools/loader.exe tools/loader.c

clean:
	rm -f $(TARGET) tools/loader.exe

.PHONY: clean loader
