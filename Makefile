.PHONY: image run run-bash help

OUTPUTDIR      := $(HOME)/work/docker/volumes/crosstool
CACHEDIR       := $(HOME)/work/docker/volumes/src

MUSL_ENABLED   := 1
GLIBC_ENABLED  := 1
NEWLIB_ENABLED := 1
NOLIB_ENABLED  := 1
TEST_ENABLED   := 1

# Use default versions from docker
GCC_VERSION           :=
BINUTILS_VERSION      :=
NEWLIB_VERSION        :=
GLIBC_VERSION         :=
MUSL_VERSION          :=
LINUX_HEADERS_VERSION :=
GMP_VERSION           :=
QEMU_VERSION          :=

# Its a bit verbose but works
VERSIONS :=
VERSIONS += $(if $(GCC_VERSION),-e GCC_VERSION=$(GCC_VERSION),)
VERSIONS += $(if $(BITUTILS_VERSION),-e BINUTILS_VERSION=$(BINUTILS_VERSION),)
VERSIONS += $(if $(NEWLIB_VERSION),-e NEWLIB_VERSION=$(NEWLIB_VERSION),)
VERSIONS += $(if $(GLIBC_VERSION),-e GLIBC_VERSION=$(GLIBC_VERSION),)
VERSIONS += $(if $(MUSL_VERSION),-e MUSL_VERSION=$(MUSL_VERSION),)
VERSIONS += $(if $(LINUX_HEADERS_VERSION),-e LINUX_HEADERS_VERSION=$(LINUX_HEADERS_VERSION),)
VERSIONS += $(if $(GMP_VERSION),-e GMP_VERSION=$(GMP_VERSION),)
VERSIONS += $(if $(QEMU_VERSION),-e QEMU_VERSION=$(QEMU_VERSION),)

DOCKER := podman
DOCKER_RUN := $(DOCKER) run -it --rm \
 -e MUSL_ENABLED=$(MUSL_ENABLED) \
 -e GLIBC_ENABLED=$(GLIBC_ENABLED) \
 -e NEWLIB_ENABLED=$(NEWLIB_ENABLED) \
 -e NOLIB_ENABLED=$(NOLIB_ENABLED) \
 -e TEST_ENABLED=$(TEST_ENABLED) \
 $(VERSIONS) \
 -v $(OUTPUTDIR):/opt/crosstool:Z \
 -v $(CACHEDIR):/opt/crossbuild/cache:Z \
 or1k-toolchain-build

image: or1k-toolchain-build/Dockerfile
	$(DOCKER) build -t or1k-toolchain-build or1k-toolchain-build/
run:
	$(DOCKER_RUN)
run-bash:
	$(DOCKER_RUN) bash

help:
	@echo "This is the helper file for running the toolchain build."
	@echo "Run one of the targets:"
	@echo
	@echo "  - help  - prints this help"
	@echo "  - image - builds the docker image and default volume directories."
	@echo "  - run   - runs the docker image"
	@echo
	@echo "Configured setup:"
	@echo "  DOCKER:     $(DOCKER)"
	@echo "  DOCKER_RUN: $(DOCKER_RUN)"
	@echo "  OUTPUTDIR:  $(OUTPUTDIR)"
	@echo "  DOCKER_RUN: $(CACHEDIR)"
