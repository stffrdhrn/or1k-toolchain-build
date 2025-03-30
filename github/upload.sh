#!/bin/bash
set -ex

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
github_dir=${DIR}
. ${DIR}/github.api

for file in $@ ; do
  echo "uploading $file"
  github_upload $file
done

