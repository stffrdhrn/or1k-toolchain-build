#!/bin/bash

set -ex

arc_date=`date -u +%Y%m%d`
version="${GCC_VERSION}-${arc_date}"

package_dir()
{
  declare dir=$1 ; shift

  # Create archive/
  tar -Jcf /opt/crosstool/${dir}-${version}.tar.xz ${dir} &
}

pushd /opt/crossbuild/output
  [ $NOLIB_ENABLED ] && package_dir "or1k-linux"
  [ $MUSL_ENABLED ] && package_dir "or1k-${VENDOR}-linux-musl"
  if [ $NEWLIB_ENABLED ] ; then
    for target in or1k-elf or1k-${VENDOR}mc-elf; do
      package_dir $target
    done
  fi
  if [ $GLIBC_ENABLED ] ; then
    for target in or1k-${VENDOR}-linux-gnu or1k-${VENDOR}hf-linux-gnu; do
      package_dir $target
    done
  fi
  wait
popd

