#!/bin/bash
set -ex

DIR=`dirname $0`
. ${DIR}/github.api

for file in $@ ; do
  echo "uploading $file"
  github_upload $file
done

