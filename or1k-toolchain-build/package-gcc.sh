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
  [ $MUSL_ENABLED ] && package_dir "or1k-linux-musl"
  [ $NEWLIB_ENABLED ] && package_dir "or1k-elf"
  wait
popd

