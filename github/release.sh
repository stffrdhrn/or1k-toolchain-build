#!/bin/bash

set -ex

GCC_VERSION=12.0.1-20220210

# The github originization we want to create the or1k-gcc release at
GITHUB_ORG=openrisc
GITHUB_PROJECT=or1k-gcc
# The remote we want to upload tags to on the remote repo
GIT_REMOTE=openrisc
# The location of your git repo
GIT_HOME=$HOME/work/gnu-toolchain/gcc

# Dry run examples
# GITHUB_ORG=stffrdhrn
# GITHUB_PROJECT=gcc
# GIT_REMOTE=shorne

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
github_dir=${DIR}
. ${DIR}/github.api

if [ -z "$release" ] ; then
  release=`date +%Y%m%d`
fi

# The local repo openrisc branch/tag, for generating the patch
ref="or1k-${GCC_VERSION}"
tag="or1k-${GCC_VERSION}-${release}"
msg="OpenRISC ${GCC_VERSION}-${release} snapshot release source and binaries"

# Create and push git tag
git_tagnpush() {
  declare ref=$1 ; shift
  declare tag=$1 ; shift
  declare remote=$1 ; shift
  declare msg=$1 ; shift

  pushd $GIT_HOME
    # check if the tag already exists at the destination, and return
    git ls-remote --tags --refs $remote | grep -e "/$tag$" && return 0

    if ! git show-ref --heads --tags --quiet $ref ; then
      echo "Failed when creating git tag, the ref $ref doesn't exist"
      exit 1
    fi
    # If we got this far the tag does exist at the remote so create and push it
    git tag -sf -m "$msg" $tag $ref
    git push -f $remote $tag
  popd
}

# Get commitish used by github release api
git_getcommit() {
  declare ref=$1; shift

  cd $GIT_HOME
    git show-ref --heads --tags -s $ref
  cd ..
}

git_tagnpush ${ref} ${tag} ${GIT_REMOTE} "${msg}"
commitish=`git_getcommit ${ref}`

# Create release
github_release "${GITHUB_ORG}/${GITHUB_PROJECT}" \
  "${tag}" \
  "${commitish}" \
  "${msg}"
