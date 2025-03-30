#!/bin/bash

set -ex

# The github originization we want to create the or1k-gcc release at
GITHUB_ORG=stffrdhrn
GITHUB_PROJECT=or1k-toolchain-build
# The remote we want to upload tags to on the remote repo
GIT_REMOTE=origin
# The location of your git repo
GIT_HOME=$HOME/work/docker/or1k-gcc-build

# Dry run examples
# GITHUB_ORG=stffrdhrn
# GITHUB_PROJECT=gcc
# GIT_REMOTE=shorne

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
github_dir=${DIR}
. ${DIR}/github.api

# Create and push git tag
git_tagnpush() {
  declare tag=$1 ; shift
  declare remote=$1 ; shift
  declare msg=$1 ; shift

  # check if the tag already exists at the destination, and return
  git -C ${GIT_HOME} ls-remote --tags --refs $remote | grep -e "/$tag$" && return 0

  # If we got this far the tag does exist at the remote so create and push it
  git -C ${GIT_HOME} tag -sf -m "$msg" $tag
  git -C ${GIT_HOME} push -f $remote $tag
}

# Get commitish used by github release api
git_getcommit() {
  declare ref=$1; shift

  git -C ${GIT_HOME} show-ref --heads --tags -s $ref
}

gcc_version=$1 ; shift
if [[ -z $gcc_version ]] ; then
  echo "usage: $0 <version>"
  exit 1
fi

# The local repo openrisc branch/tag, for generating the patch
tag="or1k-${gcc_version}"
msg="OpenRISC ${gcc_version} snapshot release source and binaries"

git_tagnpush ${tag} ${GIT_REMOTE} "${msg}"
commitish=`git_getcommit ${tag}`

# Create release
github_release "${GITHUB_ORG}/${GITHUB_PROJECT}" \
  "${tag}" \
  "${msg}"
