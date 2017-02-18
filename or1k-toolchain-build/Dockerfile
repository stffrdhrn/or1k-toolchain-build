FROM debian
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
 zlib1g-dev

LABEL maintainer Stafford Hornr <shorne@gmail.com>

# Default build versions
ENV GCC_VERSION=5.4.0
ENV BINUTILS_VERSION=2.26
ENV NEWLIB_VERSION=2.4.0
ENV MUSL_VERSION=1.1.16
ENV LINUX_HEADERS_VERSION=4.5
ENV GMP_VERSION=6.1.0
ENV MAKEOPTS="-j5"

# Make volume mount points for output + cache of tarballs
RUN mkdir -p /opt/crosstool && mkdir -p /opt/crossbuild/cache
VOLUME ["/opt/crosstool", "/opt/crossbuild/cache"]

WORKDIR /opt/crossbuild

# precache sources is too slow
COPY *.sh /opt/crossbuild/

CMD ./build-gcc.sh && ./package-gcc.sh
