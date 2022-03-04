# OpenRISC build and release scripts

This project contains a set of scripts and docker images for building toolchain
releases for the OpenRISC platform.  Once the builds are done it will upload
release artifacts to [github](https://github.com/openrisc/or1k-gcc/releases).

If you are not a release maintainer you probably don't need this.  You can just
binaries from our release page mentioned above.

## Building the toolchain

*Prerequisites*
 - the build takes about 20GB and 40 minutes on a skylake core i5

First build the docker image.  This will setup a sandboxed docker image which
will run builds for OpenRISC newlib, musl and nolib (for kernel builds).

```
docker build -t or1k-toolchain-build or1k-toolchain-build/
```

Running the build, binaries will be outputted the `/opt/crosstool` volume.  You
can choose versions of GCC, BINUTILS, NEWLIB, MUSL.  The GCC and BINUTILS
versions will be downloaded from the openrisc github repo's.

```
# The location where you have tarballs, so they dont need to be
# downloaded every time you build
CACHEDIR=/home/shorne/work/docker/volumes/src
# The location where you want your output to go
OUTPUTDIR=/home/shorne/work/docker/volumes/crosstool

docker run -it --rm \
  -e MUSL_ENABLED=1 \
  -e NEWLIB_ENABLED=1 \
  -e NOLIB_ENABLED=1 \
  -e GCC_VERSION=11.0.1 \
  -e BINUTILS_VERSION=2.36.50 \
  -e NEWLIB_VERSION=4.2.0 \
  -e LINUX_HEADERS_VERSION=5.12.2 \
  -e MUSL_VERSION=1.2.2 \
  -e GMP_VERSION=6.2.1 \
  -v ${OUTPUTDIR}:/opt/crosstool:Z \
  -v ${CACHEDIR}:/opt/crossbuild/cache:Z \
  or1k-toolchain-build
```

## Environment Parameters

You can change the build behavior without rebuilding your docker image by
passing in different environment veriables.  These can be used to change
toolchain versions or enable and disable features.

### Disabling Builds

You can disable builds by undefining any of these variables, by default all
builds are enabled.
 - `NEWLIB_ENABLED` - (default `1`) enable/disable the newlib build
 - `NOLIB_ENABLED` - (default `1`) enable/disable the nolib build
 - `MUSL_ENABLED` - (default `1) enable/disable the musl build

### Changing Versions

The source versions of components pulled into the toolchain can be adjusted.

 - `GCC_VERSION` - (default `7.2.0`) `or1k-{version}` tag downloaded from github.com/openrisc/or1k-gcc
 - `BINUTILS_VERSION` - (default `2.30`) `or1k-{version}` tag downloaded from github.com/openrisc/binutils-gdb
 - `NEWLIB_VERSION` - (default `2.4.0`) `or1k-{version}` tag downloaded from github.com/openrisc/newlib
 - `MUSL_VERSION` - (default `1.1.19`) version of musl downloaded from the musl release server
 - `LINUX_HEADERS_VERSION` - (default `4.15`) version of linux kernel, used for headers, downloaded from kernel.org
 - `GMP_VERSION` - (default `6.1.0`) version of GNU Multiple Precision Arithmetic Library (GMP) downloaded from gmplib.org

### Misc Parameters

 - `SRC_CLEANUP` - (default `1`) enable/disable deleting of source after build
   completes.  Disable this if you are debugging a toolchain build issue.  Enable
   if if you are trying to save disk space during the build.
 - `TEST_ENABLED` - (default `1`) enable/disable dejagnu tesing of toolchains
   and saving output to the `/opt/crosstool` output volume.

## Signing your work

When you are done you may want to sign your tarball archives. You can do
something like the following.

```
# Sign tar
gpg --output or1k-linux-musl-5.4.0-20170202.tar.sign --detach-sign or1k-linux-musl-5.4.0-20170202.tar

# Create clearsigned dir listing
sha256sum or1k-linux-musl-5.4.0-20170202.tar* | gpg --output sha256sums.asc --clearsign
```

## Uploading a release

This is specifically for OpenRISC maintainers.  The scripts in `github/` can
be used to create a release and upload all of the binary artifacts to github.

First setups a `~/.github.api` with a github api token defined in
`github_token`. i.e.

```
# Github api file for the curl release utilities
github_token=TOKEN
```

Next create a release

```
./github/release.sh
```

Then upload your binaries, it will automatically upload to the last release
you built.

```
./github/upload.sh ../volume/crosstool/*.tar.*
```
