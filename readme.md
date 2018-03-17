# OpenRISC build and release scripts

This project contains a set of scripts and docker images for building toolchain
releases for the OpenRISC platform.  Once the builds are done it will upload
release artifacts to [github](https://github.com/openrisc/or1k-gcc/releases).

If you are not a release maintainer you probably don't need this.  You can just
binaries from our release page mentioned above.

## Building the toolchain

*Prerequisites* the build takes about 20GB and 40 minutes on a skylake core i5

First configure the tool versions you want by editing `or1k-toolchain-build/Dockerfile`

Next build the docker image.  This will setup a sandboxed docker image which
will run builds for OpenRISC newlib, musl and nolib (for kernel builds).

```
docker build -t or1k-toolchain-build or1k-toolchain-build/
```

Running the build, binaries will be outputted to crosstool volume.

```
# The location where you have tarballs, so they dont need to be
# downloaded every time you build
CACHEDIR=/home/shorne/work/docker/volumes/src
# The location where you want your output to go
OUTPUTDIR=/home/shorne/work/docker/volumes/crosstool

docker run -it --rm \
  -v ${OUTPUTDIR}:/opt/crosstool:Z \
  -v ${CACHEDIR}:/opt/crossbuild/cache:Z \
  or1k-toolchain-build
```

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
