FROM debian:latest
RUN apt-get update && apt-get install -y \
 bison \
 build-essential \
 flex \
 git \
 libgmp-dev \
 libmpc-dev \
 libmpfr-dev \
 texinfo \
 wget \
 zip \
 zlib1g-dev \
 dejagnu \
 libncursesw5-dev \
 libncurses5-dev \
 libglib2.0-0 \
 python3.11-dev \
 pip \
 ninja-build \
 glib-2.0-dev \
 gawk \
 rsync

LABEL maintainer Stafford Horne <shorne@gmail.com>

# Default build versions
ENV GCC_VERSION=15.2.0
ENV BINUTILS_VERSION=2.46.0
ENV NEWLIB_VERSION=4.6.0.20260123
ENV GDB_VERSION=17.1
ENV MUSL_VERSION=1.2.6
ENV GLIBC_VERSION=2.43
ENV LINUX_HEADERS_VERSION=6.18.22
ENV GMP_VERSION=6.3.0
ENV QEMU_VERSION=10.2.2
ENV MAKEOPTS="-j5"
ENV SRC_CLEANUP=1
ENV TEST_ENABLED=1
ENV NOLIB_ENABLED=1
ENV MUSL_ENABLED=1
ENV NEWLIB_ENABLED=1
ENV VENDOR=none

# Make volume mount points for output + cache of tarballs
RUN mkdir -p /opt/crosstool && mkdir -p /opt/crossbuild/cache
VOLUME ["/opt/crosstool", "/opt/crossbuild/cache"]

WORKDIR /opt/crossbuild

COPY *.sh /opt/crossbuild/
ADD patches /opt/crossbuild/patches

CMD ./build-gcc.sh && ./package-gcc.sh
