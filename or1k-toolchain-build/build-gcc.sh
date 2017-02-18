#!/bin/bash

set -ex

# Build nolib GCC

mkdir linux-nolib
cd linux-nolib
  tar -xvf /opt/crossbuild/cache/or1k-${GCC_VERSION}.tar.gz
  tar -xvf /opt/crossbuild/cache/binutils-${BINUTILS_VERSION}.tar.bz2
  git clone https://github.com/stffrdhrn/buildall.git
  cd buildall
    make  # build the timer tool

    # create the buildall build config
    cat <<EOF >config
BINUTILS_SRC=/opt/crossbuild/linux-nolib/binutils-${BINUTILS_VERSION}
GCC_SRC=/opt/crossbuild/linux-nolib/or1k-gcc-or1k-${GCC_VERSION}
PREFIX=/opt/crossbuild/output/or1k-linux
EXTRA_BINUTILS_CONF=""
EXTRA_GCC_CONF=""
MAKEOPTS="$MAKEOPTS"
CHECKING=release
ECHO=/bin/echo
EOF

    ./build --toolchain openrisc
  cd ..
cd ..

# Build linux-musl GCC toolchain
mkdir linux-musl; cd linux-musl
  git clone https://github.com/openrisc/musl-cross.git
  cd musl-cross
    cp /opt/crossbuild/cache/musl-${GCC_VERSION}.tar.gz tarballs/
    cp /opt/crossbuild/cache/binutils-${BINUTILS_VERSION}.tar.bz2 tarballs/
    cp /opt/crossbuild/cache/gmp-${GMP_VERSION}.tar.bz2 tarballs/
    cp /opt/crossbuild/cache/linux-${LINUX_HEADERS_VERSION}.tar.xz tarballs/
    cat <<EOF >config.sh
BINUTILS_VERSION=${BINUTILS_VERSION}
GCC_VERSION=${GCC_VERSION}
MUSL_VERSION=${MUSL_VERSION}
LINUX_HEADERS_VERSION=${LINUX_HEADERS_VERSION}
ARCH=or1k

BINUTILS_URL=http://ftp.gnu.org/gnu/binutils/binutils-${BINUTILS_VERSION}.tar.bz2
GCC_URL=https://github.com/openrisc/or1k-gcc/archive/musl-${GCC_VERSION}.tar.gz
LINUX_HEADERS_URL=http://www.kernel.org/pub/linux/kernel/v4.x/linux-${LINUX_HEADERS_VERSION}.tar.xz

GCC_EXTRACT_DIR=or1k-gcc-musl-${GCC_VERSION}
GCC_VERSION=or1k-${GCC_VERSION}
GCC_BUILTIN_PREREQS=yes

CC_BASE_PREFIX=/opt/crossbuild/output

MAKEFLAGS=${MAKEOPTS}
EOF
    ./build.sh
  cd ..
cd ..

# Build baremetal/newlib GCC

mkdir elf; cd elf
  tar -xvf /opt/crossbuild/cache/or1k-${GCC_VERSION}.tar.gz
  tar -xvf /opt/crossbuild/cache/binutils-${BINUTILS_VERSION}.tar.bz2
  git clone https://github.com/openrisc/newlib.git

  PREFIX=/opt/crossbuild/output/or1k-elf

  export PATH=$PREFIX/bin:$PATH

  mkdir build-binutils; cd build-binutils
    ../binutils-${BINUTILS_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
      --disable-itcl \
      --disable-tk \
      --disable-tcl \
      --disable-winsup \
      --disable-gdbtk \
      --disable-libgui \
      --disable-rda \
      --disable-sid \
      --disable-sim \
      --disable-gdb \
      --with-sysroot \
      --disable-newlib \
      --disable-libgloss \
      --with-system-zlib
    make $MAKEOPTS
    make install
  cd ..

  mkdir build-gcc-stage1; cd build-gcc-stage1
    ../or1k-gcc-or1k-${GCC_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
      --enable-languages=c \
      --disable-shared \
      --disable-libssp
    make $MAKOPTS
    make install
  cd ..

  mkdir build-newlib; cd build-newlib
    ../newlib/configure --target=or1k-elf --prefix=$PREFIX
    make $MAKEOPTS
    make install
  cd ..

  mkdir build-gcc-stage2; cd build-gcc-stage2
    ../or1k-gcc-or1k-${GCC_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
      --enable-languages=c,c++ \
      --disable-shared \
      --disable-libssp \
      --with-newlib
    make $MAKEOPTS
    make install
  cd ..
cd ..
