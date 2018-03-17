#!/bin/bash

set -ex

GCC_VERSION=7.2.0

# The github originization we want to create the or1k-gcc release at
GITHUB_ORG=openrisc
# The remote we want to upload tags to on the remote repo
GIT_REMOTE=or1k
# The location of your git repo
GIT_HOME=$HOME/work/openrisc/or1k-gcc

# Dry run examples
GITHUB_ORG=stffrdhrn
GIT_REMOTE=shorne

DIR=`dirname $0`
pushd $DIR ; DIR=$PWD ; popd
. ${DIR}/github.api


release=`date -u +%Y%m%d`
base_tag="gcc-${GCC_VERSION//./_}-release"

branch="or1k-${GCC_VERSION}"
tag="or1k-${GCC_VERSION}-${release}"

# Create and push git tag
git_tagnpush() {
  declare branch=$1 ; shift
  declare tag=$1 ; shift
  declare remote=$1 ; shift

  # check if the tag already exists at the destination, and return
  git ls-remote --tags --refs $remote | grep -e "/$tag$" && return 0

  pushd $GIT_HOME
    git checkout $branch
    declare cur_branch=`git status -sb -uno`
    if [[ $cur_branch != "## $branch" ]] ; then
      echo "Failed when creating git tag, current branch status is $cur_branch, not $branch"
      exit 1
    fi
    git diff ${base_tag}..${branch} > $DIR/gcc-${tag}.patch

    # If we got this far the tag does exist at the remote so create and push it
    git tag -sf $tag
    git push -f $remote $tag
  popd
}

git_tagnpush ${branch} ${tag} ${GIT_REMOTE}

# Create release
github_release "${GITHUB_ORG}/or1k-gcc" \
  "${tag}" \
  "${branch}" \
  "OpenRISC ${GCC_VERSION} snapshot release source and binaries"
