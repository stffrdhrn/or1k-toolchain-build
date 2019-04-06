#!/bin/bash

set -ex

GCC_VERSION=9.0.1

# The github originization we want to create the or1k-gcc release at
GITHUB_ORG=openrisc
# The remote we want to upload tags to on the remote repo
GIT_REMOTE=or1k
# The location of your git repo
GIT_HOME=$HOME/work/gnu-toolchain/gcc

# Dry run examples
GITHUB_ORG=stffrdhrn
GIT_REMOTE=shorne

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
. ${DIR}/github.api


release=`date -u +%Y%m%d`

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

  # check if the tag already exists at the destination, and return
  git ls-remote --tags --refs $remote | grep -e "/$tag$" && return 0

  pushd $GIT_HOME
    if ! git show-ref --heads --tags --quiet $ref ; then
      echo "Failed when creating git tag, the ref $ref doesn't exist"
      exit 1
    fi
    declare base_tag=`git merge-base upstream/master $ref`
    git diff ${base_tag}..${ref} > $DIR/gcc-${tag}.patch

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
github_release "${GITHUB_ORG}/gcc" \
  "${tag}" \
  "${commitish}" \
  "${msg}"

$DIR/upload.sh $DIR/gcc-${tag}.patch
