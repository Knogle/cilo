# Configuration for the Cisco 3620/3640 Routers
#TARGET=c3600
#MACHCODE=0x1e
#TEXTADDR=0x80008000
#LOADADDR=0x80028000
#ifndef CROSS_COMPILE
#CROSS_COMPILE=mips-linux-gnu-
#ARCH=-march=mips32
#endif
#CFLAGS=-mno-abicalls
#LDFLAGS=-Ttext ${TEXTADDR}

# Configuration for the Cisco 3660 Routers
TARGET=c3600
MACHCODE=0x34
TEXTADDR=0x80008000
LOADADDR=0x80028000
ifndef CROSS_COMPILE
CROSS_COMPILE=$(TOOLCHAIN_DIR)/bin/mips-elf-
ARCH=-march=mips32
endif
CFLAGS=-mno-abicalls
LDFLAGS=-Ttext ${TEXTADDR}

# Configuration for the Cisco 1700 Series Routers
#TARGET=c1700
#MACHCODE=0x33
#TEXTADDR=0x80008000
#LOADADDR=0x80028000
#ifndef CROSS_COMPILE
#CROSS_COMPILE=powerpc-linux-gnu-
#ARCH=-mcpu=860 # based on 1721
#endif
#LDFLAGS=-Ttext=${TEXTADDR}

# Configuration for the Cisco 7200 Series Routers
# TARGET=c7200
# MACHCODE=0x19
# TEXTADDR=0x80008000
# LOADADDR=0x80028000
# ifndef CROSS_COMPILE
# CROSS_COMPILE=mips-linux-gnu-
# endif
# CFLAGS=-DDEBUG -mno-abicalls
# LDFLAGS=-Ttext ${TEXTADDR}

# additional CFLAGS
CFLAGS+=

# don't modify anything below here
# ===================================================================

PROG=ciscoload

CC=$(CROSS_COMPILE)gcc
AR=$(CROSS_COMPILE)ar
LD=$(CROSS_COMPILE)ld
OBJCOPY=$(CROSS_COMPILE)objcopy

MACHDIR=mach/$(TARGET)

# command to prepare a binary
RAW=${OBJCOPY} --strip-unneeded --alt-machine-code ${MACHCODE}

INCLUDE=-Iinclude/ -Imach/${TARGET} -Iinclude/mach/${TARGET}

CFLAGS+=-fno-builtin -fomit-frame-pointer -fno-pic \
	-fno-stack-protector -Wall ${ARCH} -DLOADADDR=${LOADADDR}

ASFLAGS=-D__ASSEMBLY__ -xassembler-with-cpp -traditional-cpp

LDFLAGS+=-Wl,--omagic -nostartfiles -nostdlib -Wl,--discard-all -Wl,--strip-all \
	--entry _start ${ARCH}

OBJECTS=string.o main.o ciloio.o printf.o elf_loader.o lzma_loader.o \
	LzmaDecode.o

LINKOBJ=${OBJECTS} $(MACHDIR)/promlib.o $(MACHDIR)/start.o $(MACHDIR)/platio.o\
	$(MACHDIR)/platform.o

THISFLAGS='LDFLAGS=$(LDFLAGS)' 'ASFLAGS=$(ASFLAGS)' \
	'CROSS_COMPILE=$(CROSS_COMPILE)' 'CFLAGS=$(CFLAGS)' 'CC=$(CC)'

# Toolchain Installation
TOOLCHAIN_DIR=$(HOME)/mips-toolchain

.PHONY: toolchain_install
toolchain_install:
	@mkdir -p $(TOOLCHAIN_DIR)/src || { echo "Failed to create toolchain directory"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && wget https://ftp.gnu.org/gnu/binutils/binutils-2.36.tar.gz || { echo "Failed to download binutils"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && tar -xzf binutils-2.36.tar.gz || { echo "Failed to extract binutils"; exit 1; }
	mkdir -p $(TOOLCHAIN_DIR)/src/binutils-build || { echo "Failed to create binutils build directory"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/binutils-build && ../binutils-2.36/configure --target=mips-elf --prefix=$(TOOLCHAIN_DIR) --disable-nls --disable-werror || { echo "Failed to configure binutils"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/binutils-build && make -j$(nproc) || { echo "Failed to build binutils"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/binutils-build && make install || { echo "Failed to install binutils"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && wget https://ftp.gnu.org/gnu/gcc/gcc-10.2.0/gcc-10.2.0.tar.gz || { echo "Failed to download gcc"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && tar -xzf gcc-10.2.0.tar.gz || { echo "Failed to extract gcc"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-10.2.0 && ./contrib/download_prerequisites || { echo "Failed to download gcc prerequisites"; exit 1; }
	mkdir -p $(TOOLCHAIN_DIR)/src/gcc-build || { echo "Failed to create gcc build directory"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && ../gcc-10.2.0/configure --target=mips-elf --prefix=$(TOOLCHAIN_DIR) --disable-nls --enable-languages=c,c++ --without-headers || { echo "Failed to configure gcc"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make -j$(nproc) all-gcc || { echo "Failed to build gcc (all-gcc)"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make -j$(nproc) all-target-libgcc || { echo "Failed to build gcc (all-target-libgcc)"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make install-gcc || { echo "Failed to install gcc"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make install-target-libgcc || { echo "Failed to install target libgcc"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && wget ftp://sourceware.org/pub/newlib/newlib-4.1.0.tar.gz || { echo "Failed to download newlib"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src && tar -xzf newlib-4.1.0.tar.gz || { echo "Failed to extract newlib"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && ../gcc-10.2.0/configure --target=mips-elf --prefix=$(TOOLCHAIN_DIR) --enable-languages=c,c++ --with-newlib || { echo "Failed to configure newlib"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make -j$(nproc) all-target-newlib || { echo "Failed to build newlib"; exit 1; }
	cd $(TOOLCHAIN_DIR)/src/gcc-build && make install-target-newlib || { echo "Failed to install newlib"; exit 1; }

# Main targets
all: install_toolchain build_project

.PHONY: install_toolchain build_project

install_toolchain:
	$(MAKE) toolchain_install

build_project: $(OBJECTS) ${PROG}

${PROG}: sub ${OBJECTS}
	${CC} ${LDFLAGS} ${LINKOBJ} -o ${PROG}.elf
	${RAW} ${PROG}.elf ${PROG}.bin

.c.o:
	${CC} ${CFLAGS} $(INCLUDE) -c $<

.S.o:
	${CC} ${CFLAGS} $(INCLUDE) ${ASFLAGS} -c $<

sub:
	@for i in $(MACHDIR); do \
	echo "Making all in $$i..."; \
	(cd $$i; $(MAKE) $(MFLAGS) $(THISFLAGS) -j$(nproc) all); done

subclean:
	@for i in $(MACHDIR); do \
	echo "Cleaning all in $$i..."; \
	(cd $$i; $(MAKE) $(MFLAGS) clean); done

clean: subclean
	-rm -f *.o
	-rm -f ${PROG}.elf
	-rm -f ${PROG}.bin
	@echo "Removing toolchain directory..."
	-rm -rf $(TOOLCHAIN_DIR)
	@echo "Clean complete"
