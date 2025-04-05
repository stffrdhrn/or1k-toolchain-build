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
ENV GCC_VERSION=14.2.0
ENV BINUTILS_VERSION=2.43.1
ENV NEWLIB_VERSION=4.5.0.20241231
ENV GDB_VERSION=16.2
ENV MUSL_VERSION=1.2.5
ENV GLIBC_VERSION=2.41
ENV LINUX_HEADERS_VERSION=6.12.21
ENV GMP_VERSION=6.3.0
ENV QEMU_VERSION=9.2.2
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
