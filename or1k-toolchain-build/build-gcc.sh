#!/bin/bash

set -ex

# Download anything missing

CACHE_DIR=/opt/crossbuild/cache/

OR1K_GCC_URL=https://github.com/openrisc/or1k-gcc/archive/${GCC_VERSION}.tar.gz
OR1K_BINUTILS_URL=https://github.com/openrisc/binutils-gdb/archive/${BINUTILS_VERSION}.tar.gz
OR1K_NEWLIB_URL=https://github.com/openrisc/newlib/archive/${NEWLIB_VERSION}.tar.gz

GNU_SITE=https://ftpmirror.gnu.org/gnu/
GCC_URL=${GNU_SITE}/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz
BINUTILS_URL=${GNU_SITE}/binutils/binutils-${BINUTILS_VERSION}.tar.xz
GDB_URL=${GNU_SITE}/gdb/gdb-${GDB_VERSION}.tar.xz
GMP_URL=${GNU_SITE}/gmp/gmp-${GMP_VERSION}.tar.xz
GLIBC_URL=${GNU_SITE}/glibc/glibc-${GLIBC_VERSION}.tar.xz

NEWLIB_URL=ftp://sourceware.org/pub/newlib/newlib-${NEWLIB_VERSION}.tar.gz
LINUX_HEADERS_URL=https://cdn.kernel.org/pub/linux/kernel/v${LINUX_HEADERS_VERSION:0:1}.x/linux-${LINUX_HEADERS_VERSION}.tar.xz
QEMU_URL=https://download.qemu.org/qemu-${QEMU_VERSION}.tar.xz

GCC_TARBALL=$CACHE_DIR/`basename $GCC_URL`
BINUTILS_TARBALL=$CACHE_DIR/`basename $BINUTILS_URL`
GDB_TARBALL=$CACHE_DIR/`basename $GDB_URL`
NEWLIB_TARBALL=$CACHE_DIR/`basename $NEWLIB_URL`
LINUX_HEADERS_TARBALL=$CACHE_DIR/`basename $LINUX_HEADERS_URL`
GMP_TARBALL=$CACHE_DIR/`basename $GMP_URL`
QEMU_TARBALL=$CACHE_DIR/`basename $QEMU_URL`

# Dates and version used for artifacts
arc_date=`date -u +%Y%m%d`
version="${GCC_VERSION}-${arc_date}"

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
  typeset gcc_dir=$1 ; shift
  typeset tag=$1 ; shift

  make -C ${gcc_dir} check-gcc

  gzip -c gcc/testsuite/gcc/gcc.log > /opt/crosstool/${tag}-gcc-${version}.log.gz
  cp gcc/testsuite/gcc/gcc.sum /opt/crosstool/${tag}-gcc-${version}.sum
  # Rename g++ to gxx for easier web urls
  gzip -c gcc/testsuite/g++/g++.log > /opt/crosstool/${tag}-gxx-${version}.log.gz
  cp gcc/testsuite/g++/g++.sum /opt/crosstool/${tag}-gxx-${version}.sum
}
gen_release_notes()
{
  {

    echo "## OpenRISC GCC Toolchain $version"
    echo "These toolchains were built using the "
    echo "[or1k-toolchain-build](https://github.com/stffrdhrn/or1k-toolchain-build) "
    echo " environment configured with the following versions: "
    echo " - openrisc/or1k-gcc : ${GCC_VERSION}"
    echo " - openrisc/binutils-gdb : ${BINUTILS_VERSION}"
    echo " - linux headers : ${LINUX_HEADERS_VERSION}"
    echo " - gmp : ${GMP_VERSION}"
    if [ $NEWLIB_ENABLED ] ; then
      echo " - openrisc/newlib (elf toolchain) : ${NEWLIB_VERSION}"
    fi
    if [ $MUSL_ENABLED ] ; then
      echo " - musl (linux-musl toolchain) : ${MUSL_VERSION}"
    fi
    echo
    if [ $TEST_ENABLED ] ; then
    echo "## Test Results"
      echo "Tests for toolchains were run using dejagnu board configs found in"
      echo "[or1k-utils](https://github.com/stffrdhrn/or1k-utils)."
      echo "The test results for the toolchains are as follows:"
      echo
      echo '```'
      grep -h -A10 "Summary ==" /opt/crosstool/or1k-*${version}.sum
      echo '```'
    fi

  } > /opt/crosstool/relnotes-${version}.md
}

check_and_download $GCC_URL
check_and_download $BINUTILS_URL
check_and_download $NEWLIB_URL
check_and_download $GDB_URL
check_and_download $GLIBC_URL
check_and_download $LINUX_HEADERS_URL
check_and_download $GMP_URL

# Setup testing infra

if [ $TEST_ENABLED ] ; then

  if [ ! -d "or1k-utils" ] ; then
    git clone https://github.com/stffrdhrn/or1k-utils.git
  fi

  check_and_download $QEMU_URL

  QEMU_PREFIX=$PWD/or1k-qemu
  if [ ! -d "$QEMU_PREFIX" ] ; then
    tar -xf $QEMU_TARBALL
    mkdir qemu-${QEMU_VERSION}/build
    cd qemu-${QEMU_VERSION}/build
       ../../or1k-utils/qemu/config.qemu --prefix=$QEMU_PREFIX
       make $MAKEOPTS
       make install
       $QEMU_PREFIX/bin/qemu-or1k
    cd ../..
  fi

  export PATH=$QEMU_PREFIX/bin:$PATH
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
BINUTILS_SRC=/opt/crossbuild/linux-nolib/binutils-${BINUTILS_VERSION}
GCC_SRC=/opt/crossbuild/linux-nolib/gcc-${GCC_VERSION}
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
    git clone https://github.com/richfelker/musl-cross-make.git
    cd musl-cross-make
      mkdir sources/
      cp $GCC_TARBALL sources/
      cp $BINUTILS_TARBALL sources/
      cp $GMP_TARBALL sources/
      cp $LINUX_HEADERS_TARBALL sources/

      PREFIX=/opt/crossbuild/output/or1k-linux-musl

      OLD_PATH=$PATH
      export PATH=$PREFIX/bin:$PATH

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

OUTPUT = ${PREFIX}
EOF
      make $MAKEOPTS
      make install

      if [ $TEST_ENABLED ] ; then
        # Fixup since ld-musl-or1k.so.1 links to /lib/libc.so which doesn't work
        # via qemu-or1k symlink resolution
        pushd /opt/crossbuild/output/or1k-linux-musl/or1k-linux-musl/lib
          ln -sf libc.so ld-musl-or1k.so.1
        popd

        run_make_check "./build/local/or1k-linux-musl/obj_gcc/" "or1k-linux-musl"
      fi
      export PATH=$OLD_PATH
    cd ..
  cd ..

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf linux-musl
fi

# Build baremetal/newlib GCC

if [ $NEWLIB_ENABLED ] ; then
  mkdir elf; cd elf
    tar -xf $GCC_TARBALL
    tar -xf $BINUTILS_TARBALL
    tar -xf $NEWLIB_TARBALL
    tar -xf $GDB_TARBALL

    PREFIX=/opt/crossbuild/output/or1k-elf

    OLD_PATH=$PATH
    export PATH=$PREFIX/bin:$PATH

    export NOTIFY=n
    export INSTALLDIR=$PREFIX
    export BUILDDIR=$PWD
    export GCC_SRC=$BUILDDIR/gcc-${GCC_VERSION}
    export BINUTILS_SRC=$BUILDDIR/binutils-${BINUTILS_VERSION}
    export GDB_SRC=$BUILDDIR/gdb-${GDB_VERSION}
    export NEWLIB_SRC=$BUILDDIR/newlib-${NEWLIB_VERSION}
    ../or1k-utils/toolchains/newlib.build
    cat ./log/newlib-build.log

    if [ $TEST_ENABLED ] ; then
      run_make_check "./build-gcc" "or1k-elf"
    fi
    export PATH=$OLD_PATH
  cd ..

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf elf
fi

gen_release_notes
