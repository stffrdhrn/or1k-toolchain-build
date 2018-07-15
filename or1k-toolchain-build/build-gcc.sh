#!/bin/bash

set -ex

# Download anything missing

CACHE_DIR=/opt/crossbuild/cache/

GCC_URL=https://github.com/stffrdhrn/gcc/archive/or1k-${GCC_VERSION}.tar.gz
BINUTILS_URL=https://github.com/stffrdhrn/binutils-gdb/archive/or1k-${BINUTILS_VERSION}.tar.gz
LINUX_HEADERS_URL=http://www.kernel.org/pub/linux/kernel/v4.x/linux-${LINUX_HEADERS_VERSION}.tar.xz
GMP_URL=https://gmplib.org/download/gmp/gmp-${GMP_VERSION}.tar.bz2
QEMU_URL=http://shorne.noip.me/downloads/or1k-qemu-2.12.50.tar.xz

GCC_TARBALL=$CACHE_DIR/`basename $GCC_URL`
BINUTILS_TARBALL=$CACHE_DIR/`basename $BINUTILS_URL`
LINUX_HEADERS_TARBALL=$CACHE_DIR/`basename $LINUX_HEADERS_URL`
GMP_TARBALL=$CACHE_DIR/`basename $GMP_URL`
QEMU_TARBALL=$CACHE_DIR/`basename $QEMU_URL`

check_and_download()
{
  typeset url=$1 ; shift

  filename=`basename $url`
  if [ ! -f $CACHE_DIR/$filename ] ; then
    wget --directory-prefix=$CACHE_DIR $url
  fi
}

run_make_check()
{
  typeset tag=$1 ; shift

  typeset arc_date=`date -u +%Y%m%d`
  typeset version="${GCC_VERSION}-${arc_date}"

  make check-gcc

  for tool in "gcc" "g++"; do
    cp gcc/testsuite/${tool}/${tool}.log /opt/crosstool/${tag}-${tool}-${version}.log
    cp gcc/testsuite/${tool}/${tool}.sum /opt/crosstool/${tag}-${tool}-${version}.sum
  done
}

check_and_download $GCC_URL
check_and_download $BINUTILS_URL
check_and_download $LINUX_HEADERS_URL
check_and_download $GMP_URL

# Setup testing infra

if [ $TEST_ENABLED ] ; then
  check_and_download $QEMU_URL

  if [ ! -d "or1k-qemu" ] ; then
    tar -xf $QEMU_TARBALL
  fi

  if [ ! -d "or1k-utils" ] ; then
    git clone https://github.com/stffrdhrn/or1k-utils.git
  fi

  export PATH=$PWD/or1k-qemu/bin:$PATH
  export DEJAGNU=$PWD/or1k-utils/site.exp
fi

# Build nolib GCC

if [ $NOLIB_ENABLED ] ; then
  mkdir linux-nolib
  cd linux-nolib
    tar -xf $GCC_TARBALL
    tar -xf $BINUTILS_TARBALL
    git clone https://github.com/stffrdhrn/buildall.git
    cd buildall
      make  # build the timer tool

      # create the buildall build config
      cat <<EOF >config
BINUTILS_SRC=/opt/crossbuild/linux-nolib/binutils-gdb-or1k-${BINUTILS_VERSION}
GCC_SRC=/opt/crossbuild/linux-nolib/gcc-or1k-${GCC_VERSION}
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

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf linux-nolib
fi

# Build linux-musl GCC toolchain

if [ $MUSL_ENABLED ] ; then
  mkdir linux-musl; cd linux-musl
    git clone https://github.com/stffrdhrn/musl-cross-make.git
    cd musl-cross-make
      git checkout or1k
      mkdir sources/
      cp $GCC_TARBALL sources/
      cp $BINUTILS_TARBALL sources/
      cp $GMP_TARBALL sources/
      cp $LINUX_HEADERS_TARBALL sources/

      # Populate sha1 hashes that don't exist, not secure!
      cd sources/
        for tarball in * ; do
          [ -f "../hashes/${tarball}.sha1" ] || sha1sum $tarball > "../hashes/${tarball}.sha1"
        done
      cd ..
      # Touch sources so make thinks we downloaded after sha1
      touch sources/*
      cat <<EOF >config.mak
TARGET = or1k-linux-musl
BINUTILS_VER = ${BINUTILS_VERSION}
GCC_VER = ${GCC_VERSION}
MUSL_VER = ${MUSL_VERSION}
LINUX_VER = ${LINUX_HEADERS_VERSION}

OUTPUT = /opt/crossbuild/output/or1k-linux-musl
EOF
      make -j 4
      make install

      if [ $TEST_ENABLED ] ; then
        # Fixup since ld-musl-or1k.so.1 links to /lib/libc.so which doesn't work
        # via qemu-or1k symlink resolution
        pushd /opt/crossbuild/output/or1k-linux-musl/or1k-linux-musl/lib
          ln -sf libc.so ld-musl-or1k.so.1
        popd

        cd build/local/or1k-linux-musl/obj_gcc/
        run_make_check "or1k-linux-musl"
      fi
    cd ..
  cd ..

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf linux-musl
fi

# Build baremetal/newlib GCC

if [ $NEWLIB_ENABLED ] ; then
  mkdir elf; cd elf
    tar -xvf /$GCC_TARBALL
    tar -xvf $BINUTILS_TARBALL
    git clone https://github.com/openrisc/newlib.git

    PREFIX=/opt/crossbuild/output/or1k-elf

    export PATH=$PREFIX/bin:$PATH

    mkdir build-binutils; cd build-binutils
      ../binutils-gdb-or1k-${BINUTILS_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
      --disable-itcl \
      --disable-tk \
      --disable-tcl \
      --disable-winsup \
      --disable-gdbtk \
      --disable-rda \
      --disable-sid \
      --with-sysroot \
      --disable-newlib \
      --disable-libgloss \
      --with-system-zlib
      make $MAKEOPTS
      make install
    cd ..

    mkdir build-gcc-stage1; cd build-gcc-stage1
      ../gcc-or1k-${GCC_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
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
      ../gcc-or1k-${GCC_VERSION}/configure --target=or1k-elf --prefix=$PREFIX \
      --enable-languages=c,c++ \
      --disable-shared \
      --disable-libssp \
      --with-newlib
      make $MAKEOPTS
      make install

      if [ $TEST_ENABLED ] ; then
        run_make_check "or1k-elf"
      fi
    cd ..
  cd ..

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf elf
fi
