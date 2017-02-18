#!/bin/bash

set -ex

arc_date=`date -u +%Y%m%d`
version="${GCC_VERSION}-${arc_date}"

package_dir()
{
  declare dir=$1 ; shift

  # Create archive/
  tar -cf ${dir}-${version}.tar ${dir}
  gzip -k ${dir}-${version}.tar &
  xz -k ${dir}-${version}.tar &
  bzip2 -k ${dir}-${version}.tar &
}

pushd /opt/crossbuild/output
  package_dir "or1k-linux"
  package_dir "or1k-linux-musl"
  package_dir "or1k-elf"
  wait

  mv *.tar* /opt/crosstool
popd

