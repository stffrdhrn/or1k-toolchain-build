# OpenRISC build and release scripts

This project contains a set of scripts and docker images for building toolchain
releases for the OpenRISC platform.  Once the builds are done we upload
release artifacts to [github](https://github.com/openrisc/or1k-gcc/releases).

If you are not a release maintainer you probably don't need this.  You can get
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
  -e GLIBC_ENABLED=1 \
  -e NEWLIB_ENABLED=1 \
  -e NOLIB_ENABLED=1 \
  -e GCC_VERSION=14.2.0 \
  -e BINUTILS_VERSION=2.43.1 \
  -e NEWLIB_VERSION=4.5.0.20241231 \
  -e GLIBC_VERSION=2.41 \
  -e MUSL_VERSION=1.2.5 \
  -e LINUX_HEADERS_VERSION=6.13.8 \
  -e GMP_VERSION=6.3.0 \
  -e QEMU_VERSION=9.2.2 \
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

 - `GCC_VERSION` - (default `14.2.0`) version downloaded from: https://ftpmirror.gnu.org/gnu/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz
 - `BINUTILS_VERSION` - (default `2.43.1`) version downloaded from: https://ftpmirror.gnu.org/gnu//binutils/binutils-2.43.1.tar.xz
 - `NEWLIB_VERSION` - (default `4.5.0.20241231`) version downloaded from: ftp://sourceware.org/pub/newlib/newlib-4.5.0.20241231.tar.xz
 - `GDB_VERSION` - (default `16.2`) version downloaded from: https://ftpmirror.gnu.org/gnu/gdb/gdb-16.2.tar.xz
 - `GLIBC_VERSION` - (default `2.41`) version downloaded from: https://ftpmirror.gnu.org/gnu/glibc/glibc-2.41.tar.xz
 - `MUSL_VERSION` - (default `1.2.5`) version of musl downloaded from: https://musl.libc.org/releases/musl-1.2.5.tar.gz
 - `LINUX_HEADERS_VERSION` - (default `6.13.8`) version of linux kernel, used for headers, downloaded from: https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.13.8.tar.xz
 - `GMP_VERSION` - (default `6.3.0`) version of GNU Multiple Precision Arithmetic Library (GMP) downloaded from: https://gmplib.org/download/gmp/gmp-6.3.0.tar.xz
 - `QEMU_VERSION` - (default `9.2.2`) version of QEMU for running tests downloaded from: https://download.qemu.org/qemu-9.2.2.tar.xz

Git tags, special `or1k-{version}` versions allow downloading and building from
OpenRISC development repo's.  This may be useful when a feature needs to be
released before an official release is made upstream. This is supported for:

 - `GCC_VERSION` - `or1k-{version}` tag downloaded from github.com/openrisc/or1k-gcc
 - `BINUTILS_VERSION` - `or1k-{version}` tag downloaded from github.com/openrisc/binutils-gdb
 - `GDB_VERSION` - `or1k-{version}` tag downloaded from github.com/openrisc/binutils-gdb
 - `NEWLIB_VERSION` - `or1k-{version}` tag downloaded from github.com/openrisc/newlib
 - `GLIBC_VERSION` - `or1k-{version}` tag downloaded from github.com/openrisc/or1k-glibc

### Misc Parameters

 - `SRC_CLEANUP` - (default `1`) enable/disable deleting of source after build
   completes.  Disable this if you are debugging a toolchain build issue.  Enable
   if if you are trying to save disk space during the build.
 - `TEST_ENABLED` - (default `1`) enable/disable dejagnu tesing of toolchains
   and saving output to the `/opt/crosstool` output volume.
 - `VENDOR` - (default `none`) the vendor name to use in the toolchain triplet. i.e. `or1k-none-linux-gnu`.
   Change this if you want to identify your release uniquely.

## Choosing versions

This tool is used for creating stable releases, at the moment we manually track stable
releases and make releases periodically.  Watch for new releases for each project at:

 * [GCC](https://gcc.gnu.org/releases.html) - Released 2 times a year during May and August
 * [GNU Software releases](https://www.gnu.org/software/recent-releases.html) to track:
    * GLIBC - releases about 2 times a year around January and July
    * Binutils - releases about 2 times a year around the end of January and end of July
    * GDB - releases about 2 times a year
    * GMP - releases once every 2-3 years
 * [Linux Kernel](https://kernel.org) - Used for linux headers we don't need to update too often.
 * [MUSL libc](https://musl.libc.org/releases.html) - Releases about once a year.
 * [newlib](https://sourceware.org/newlib/) - Releases about once a year in December.
 * [QEMU](https://www.qemu.org) - Periodically released, used for running tests not part of toolchain.

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
