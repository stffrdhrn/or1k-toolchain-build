#!/bin/bash

set -ex

# Download anything missing

BUILD_ROOT=/opt/crossbuild
CACHE_DIR=${BUILD_ROOT}/cache
OUTPUT_DIR=${BUILD_ROOT}/output
PATCH_DIR=${BUILD_ROOT}/patches

OR1K_GITHUB_SITE=https://github.com/openrisc
GNU_SITE=https://ftpmirror.gnu.org/gnu
SOURCEWARE_SITE=ftp://sourceware.org/pub
KERNEL_SITE=https://cdn.kernel.org/pub/linux/kernel
QEMU_SITE=https://download.qemu.org/

# Dates and version used for artifacts
arc_date=`date -u +%Y%m%d`
version="${GCC_VERSION}-${arc_date}"

package_url()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  if [[ $ver = or1k-* ]]; then
    case $pkg in
      gcc)          echo $OR1K_GITHUB_SITE/or1k-gcc/archive/${ver}.tar.gz ;;
      glibc)        echo $OR1K_GITHUB_SITE/or1k-glibc/archive/${ver}.tar.gz ;;
      binutils|gdb) echo $OR1K_GITHUB_SITE/binutils-gdb/archive/${ver}.tar.gz ;;
      *)            echo $OR1K_GITHUB_SITE/${pkg}/archive/${ver}.tar.gz ;;
    esac
    return
  fi

  case $pkg in
    newlib) echo $SOURCEWARE_SITE/${pkg}/${pkg}-${ver}.tar.gz ;;
    linux)  echo $KERNEL_SITE/v${ver:0:1}.x/linux-${ver}.tar.xz ;;
    qemu)   echo $QEMU_SITE/${pkg}-${ver}.tar.xz ;;
    gcc)    echo $GNU_SITE/gcc/gcc-${ver}/gcc-${ver}.tar.xz ;;
    # Fallback to gnu as most things are this!
    *)      echo $GNU_SITE/${pkg}/${pkg}-${ver}.tar.xz ;;
  esac
}

package_tarball()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  typeset url=$(package_url $pkg $ver)
  echo $CACHE_DIR/$(basename $url)
}

check_and_download()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  typeset url=$(package_url $pkg $ver)

  filename=`basename $url`
  if [ ! -f $CACHE_DIR/$filename ] ; then
    wget --directory-prefix=$CACHE_DIR $url
    sha1sum $CACHE_DIR/$filename > $CACHE_DIR/$filename.sha1
  fi
}

archive_src()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  # For or1k versions we pull from github and the extracted archive
  # is a bit different from the tarball, it includes the repo name.
  if [[ $ver = or1k-* ]]; then
    case $pkg in
      gcc)          echo $PWD/or1k-gcc-${ver} ;;
      glibc)        echo $PWD/or1k-glibc-${ver} ;;
      binutils|gdb) echo $PWD/binutils-gdb-${ver} ;;
      # newlib is normal
      *)            echo $PWD/${pkg}-${ver} ;;
    esac
    return
  fi

  # All others are normal
  echo $PWD/${pkg}-${ver}
}

archive_src_patch()
{
  typeset dir=$1 ; shift
  typeset pkg=$1 ; shift

  if [ -d ${PATCH_DIR}/${pkg} ] ; then
     for patch in ${PATCH_DIR}/${pkg}/*.patch ; do
       patch -d $dir -p1 < $patch
     done
  fi
}

archive_extract()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  # First check if the archive is available, if not, get it
  check_and_download $pkg $ver

  typeset src=$(archive_src $pkg $ver)

  # Next extract it to the current directory if we
  # haven't already, may have been for binutils-gdb
  if [ ! -d $src ] ; then
    tar -xf $(package_tarball $pkg $ver)

    # Apply any patches
    archive_src_patch $src $pkg
  fi
}

archive_copy()
{
  typeset pkg=$1 ; shift
  typeset ver=$1 ; shift

  # First check if the archive is available, if not, get it
  check_and_download $pkg $ver

  mkdir -p sources/
  tarball=$(package_tarball $pkg $ver)

  cp $tarball.sha1 hashes/
  # Copy sources second so make thinks we downloaded after sha1
  cp $tarball sources/
}

run_make_check()
{
  typeset gcc_dir=$1 ; shift
  typeset tag=$1 ; shift

  make -C ${gcc_dir} check-gcc

  xz -c ${gcc_dir}/gcc/testsuite/gcc/gcc.log > /opt/crosstool/${tag}-gcc-${version}.log.xz
  cp    ${gcc_dir}/gcc/testsuite/gcc/gcc.sum   /opt/crosstool/${tag}-gcc-${version}.sum
  # Rename g++ to gxx for easier web urls
  xz -c ${gcc_dir}/gcc/testsuite/g++/g++.log > /opt/crosstool/${tag}-gxx-${version}.log.xz
  cp    ${gcc_dir}/gcc/testsuite/g++/g++.sum   /opt/crosstool/${tag}-gxx-${version}.sum
}

gen_release_notes()
{
  {

    echo "## OpenRISC GCC Toolchain $version"
    echo "These toolchains were built using the "
    echo "[or1k-toolchain-build](https://github.com/stffrdhrn/or1k-toolchain-build) "
    echo " environment configured with the following versions: "
    echo " - gcc : ${GCC_VERSION}"
    echo " - binutils : ${BINUTILS_VERSION}"
    echo " - gdb : ${GDB_VERSION}"
    echo " - linux headers : ${LINUX_HEADERS_VERSION}"
    echo " - gmp : ${GMP_VERSION}"
    if [ $NEWLIB_ENABLED ] ; then
      echo " - newlib (elf toolchain) : ${NEWLIB_VERSION}"
    fi
    if [ $MUSL_ENABLED ] ; then
      echo " - musl (linux-musl toolchain) : ${MUSL_VERSION}"
    fi
    if [ $GLIBC_ENABLED ] ; then
      echo " - glibc (linux-gnu toolchain) : ${GLIBC_VERSION}"
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

# Get latest build and config scripts

if [ ! -d "or1k-utils" ] ; then
  git clone https://github.com/stffrdhrn/or1k-utils.git
fi

# Setup testing infra

if [ $TEST_ENABLED ] ; then

  QEMU_PREFIX=$PWD/or1k-qemu
  if [ ! -d "$QEMU_PREFIX" ] ; then
    archive_extract qemu ${QEMU_VERSION}

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
    archive_extract gcc ${GCC_VERSION}
    archive_extract binutils ${BINUTILS_VERSION}

    GCC_SRC=$(archive_src gcc ${GCC_VERSION})
    BINUTILS_SRC=$(archive_src binutils ${BINUTILS_VERSION})

    git clone https://github.com/stffrdhrn/buildall.git
    cd buildall
      make  # build the timer tool

      # create the buildall build config
      cat <<EOF >config
BINUTILS_SRC=${BINUTILS_SRC}
GCC_SRC=${GCC_SRC}
PREFIX=${OUTPUT_DIR}/or1k-linux
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
    archive_src_patch musl-cross-make musl-cross-make
    cd musl-cross-make

      # Copy archive to sources/ and hash to hashes/
      archive_copy gcc ${GCC_VERSION}
      archive_copy binutils ${BINUTILS_VERSION}
      archive_copy gmp ${GMP_VERSION}
      archive_copy linux ${LINUX_HEADERS_VERSION}

      TARGET=or1k-${VENDOR}-linux-musl
      PREFIX=${OUTPUT_DIR}/${TARGET}

      OLD_PATH=$PATH
      export PATH=$PREFIX/bin:$PATH

      cat <<EOF >config.mak
TARGET = ${TARGET}
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
        pushd ${PREFIX}/lib
          ln -sf libc.so ld-musl-or1k.so.1
        popd

        run_make_check "./build/local/${TARGET}/obj_gcc/" "${TARGET}"
      fi
      export PATH=$OLD_PATH
    cd ..
  cd ..

  # Cleanup after build
  [ $SRC_CLEANUP ] && rm -rf linux-musl
fi

# Build baremetal/newlib GCC

if [ $NEWLIB_ENABLED ] ; then
  # build newlib plain and multicore variants
  for target in or1k-elf or1k-${VENDOR}mc-elf; do
    mkdir $target; cd $target

      archive_extract gcc ${GCC_VERSION}
      archive_extract binutils ${BINUTILS_VERSION}
      archive_extract newlib ${NEWLIB_VERSION}
      archive_extract gdb ${GDB_VERSION}

      PREFIX=${OUTPUT_DIR}/${target}

      OLD_PATH=$PATH
      export PATH=$PREFIX/bin:$PATH

      # Setup overrides for newlib.config
      export NOTIFY=n
      export BUILDDIR=$PWD
      export GCC_SRC=$(archive_src gcc ${GCC_VERSION})
      export BINUTILS_SRC=$(archive_src binutils ${BINUTILS_VERSION})
      export GDB_SRC=$(archive_src gdb ${GDB_VERSION})
      export NEWLIB_SRC=$(archive_src newlib ${NEWLIB_VERSION})
      export INSTALLDIR=$PREFIX
      export CROSS=${target}
      ../or1k-utils/toolchains/newlib.build

      if [ $TEST_ENABLED ] ; then
        run_make_check "./build-gcc" "${target}"
      fi
      export PATH=$OLD_PATH
    cd ..
    # Cleanup after build
    [ $SRC_CLEANUP ] && rm -rf $target
  done
fi

if [ $GLIBC_ENABLED ] ; then
  for target in or1k-${VENDOR}-linux-gnu or1k-${VENDOR}hf-linux-gnu; do
    mkdir ${target}; cd ${target}

      archive_extract gcc ${GCC_VERSION}
      archive_extract binutils ${BINUTILS_VERSION}
      archive_extract linux ${LINUX_HEADERS_VERSION}
      archive_extract glibc ${GLIBC_VERSION}

      PREFIX=${OUTPUT_DIR}/${target}

      OLD_PATH=$PATH
      export PATH=$PREFIX/bin:$PATH

      # Setup overrides for glibc.config
      export NOTIFY=n
      export BUILDDIR=$PWD
      export GCC_SRC=$(archive_src gcc ${GCC_VERSION})
      export BINUTILS_SRC=$(archive_src binutils ${BINUTILS_VERSION})
      export LINUX_SRC=$(archive_src linux ${LINUX_HEADERS_VERSION})
      export GLIBC_SRC=$(archive_src glibc ${GLIBC_VERSION})
      export INSTALLDIR=$PREFIX
      export CROSS=${target}
      ../or1k-utils/toolchains/glibc.build

      if [ $TEST_ENABLED ] ; then
        run_make_check "./build-gcc" "${target}"
      fi
      export PATH=$OLD_PATH
    cd ..

    # Cleanup after build
    [ $SRC_CLEANUP ] && rm -rf $target
  done
fi

gen_release_notes
