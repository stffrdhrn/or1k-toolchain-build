#!/bin/bash

set -ex

GCC_VERSION=5.4.0
RELEASE=`date -u +%Y%m%d`
GIT_HOME=$HOME/work/openrisc/or1k-gcc

DIR=`dirname $0`
. ${DIR}/github.api

tag="or1k-${GCC_VERSION}-${RELEASE}"
branch="or1k-5.4.0"

# Create and push git tag
pushd $GIT_HOME
  cur_branch=`git status -sb -uno`
  if [[ $cur_branch != "## $branch" ]] ; then
     echo "Failed when creating git tag, current branch status is $cur_branch, not $branch"
     exit 1
  fi
  git tag -sf $tag
  git push -f shorne $tag
popd

github_release "stffrdhrn/or1k-gcc" \
  "${tag}" \
  "${branch}" \
  "OpenRISC ${GCC_VERSION} snapshot release source and binaries"
