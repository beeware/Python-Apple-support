#
# Useful targets:
# - all                       - build everything
# - macOS                     - build everything for macOS
# - iOS                       - build everything for iOS
# - tvOS                      - build everything for tvOS
# - watchOS                   - build everything for watchOS
# - OpenSSL-macOS   - build OpenSSL for macOS
# - OpenSSL-iOS     - build OpenSSL for iOS
# - OpenSSL-tvOS    - build OpenSSL for tvOS
# - OpenSSL-watchOS - build OpenSSL for watchOS
# - BZip2-macOS     - build BZip2 for macOS
# - BZip2-iOS       - build BZip2 for iOS
# - BZip2-tvOS      - build BZip2 for tvOS
# - BZip2-watchOS   - build BZip2 for watchOS
# - XZ-macOS        - build XZ for macOS
# - XZ-iOS          - build XZ for iOS
# - XZ-tvOS         - build XZ for tvOS
# - XZ-watchOS      - build XZ for watchOS
# - Python-macOS    - build Python for macOS
# - Python-iOS      - build Python for iOS
# - Python-tvOS     - build Python for tvOS
# - Python-watchOS  - build Python for watchOS

# Current director
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=custom

MACOSX_DEPLOYMENT_TARGET=10.8

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=3.8.3
PYTHON_VER=$(basename $(PYTHON_VERSION))

OPENSSL_VERSION_NUMBER=1.1.1
OPENSSL_REVISION=g
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

BZIP2_VERSION=1.0.8

XZ_VERSION=5.2.5

# Supported OS
OS=macOS iOS tvOS watchOS

# macOS targets
TARGETS-macOS=macosx.x86_64
CFLAGS-macOS=-mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET)

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphoneos.arm64
CFLAGS-iOS=-mios-version-min=8.0 -fembed-bitcode
CFLAGS-iphoneos.arm64=
CFLAGS-iphonesimulator.x86_64=

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvos.arm64
CFLAGS-tvOS=-mtvos-version-min=9.0 -fembed-bitcode
CFLAGS-appletvos.arm64=
CFLAGS-appletvsimulator.x86_64=
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.i386 watchos.armv7k
CFLAGS-watchOS=-mwatchos-version-min=4.0 -fembed-bitcode
CFLAGS-watchsimulator.i386=
CFLAGS-watchos.armv7k=
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

# override machine types for arm64
MACHINE_DETAILED-arm64=aarch64
MACHINE_SIMPLE-arm64=arm

all: $(foreach os,$(OS),$(os))

# Clean all builds
clean:
	rm -rf build dist

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

downloads: downloads/openssl-$(OPENSSL_VERSION).tgz downloads/bzip2-$(BZIP2_VERSION).tgz downloads/xz-$(XZ_VERSION).tgz downloads/Python-$(PYTHON_VERSION).tgz

update-patch:
	# Generate a diff from the clone of the python/cpython Github repository
	# Requireds patchutils (installable via `brew install patchutils`)
	if [ -z "$(PYTHON_REPO_DIR)" ]; then echo "\n\nPYTHON_REPO_DIR must be set to the root of your Python github checkout\n\n"; fi
	cd $(PYTHON_REPO_DIR) && git diff -D v$(PYTHON_VERSION) $(PYTHON_VER) | filterdiff -X $(PROJECT_DIR)/patch/Python/diff-exclude.lst -p 1 --clean > $(PROJECT_DIR)/patch/Python/Python.patch

###########################################################################
# OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	rm -rf build/*/openssl-$(OPENSSL_VERSION)-* \
		build/*/libssl.a build/*/libcrypto.a \
		build/*/OpenSSL

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	mkdir -p downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi


###########################################################################
# BZip2
###########################################################################

# Clean the bzip2 project
clean-bzip2:
	rm -rf build/*/bzip2-$(BZIP2_VERSION)-* \
		build/*/bzip2

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/bzip2-$(BZIP2_VERSION).tgz ]; then curl --fail -L https://sourceware.org/pub/bzip2/bzip2-$(BZIP2_VERSION).tar.gz -o downloads/bzip2-$(BZIP2_VERSION).tgz; fi

###########################################################################
# XZ (LZMA)
###########################################################################

# Clean the XZ project
clean-xz:
	rm -rf build/*/xz-$(XZ_VERSION)-* \
		build/*/xz

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/xz-$(XZ_VERSION).tgz ]; then curl --fail -L http://tukaani.org/xz/xz-$(XZ_VERSION).tar.gz -o downloads/xz-$(XZ_VERSION).tgz; fi

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf \
		build/*/Python-$(PYTHON_VERSION)-* \
		build/*/libpython$(PYTHON_VER).a \
		build/*/pyconfig-*.h \
		build/*/Python

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

PYTHON_DIR-macOS=build/macOS/Python-$(PYTHON_VERSION)-macosx.x86_64
PYTHON_HOST=$(PYTHON_DIR-macOS)/dist/lib/libpython$(PYTHON_VER).a

# Build for specified target (from $(TARGETS))
#
# Parameters:
# - $1 - target
# - $2 - OS
define build-target
ARCH-$1=$$(subst .,,$$(suffix $1))
ifdef MACHINE_DETAILED-$$(ARCH-$1)
MACHINE_DETAILED-$1=$$(MACHINE_DETAILED-$$(ARCH-$1))
else
MACHINE_DETAILED-$1=$$(ARCH-$1)
endif
ifdef MACHINE_SIMPLE-$$(ARCH-$1)
MACHINE_SIMPLE-$1=$$(MACHINE_SIMPLE-$$(ARCH-$1))
else
MACHINE_SIMPLE-$1=$$(ARCH-$1)
endif
SDK-$1=$$(basename $1)

SDK_ROOT-$1=$$(shell xcrun --sdk $$(SDK-$1) --show-sdk-path)
CC-$1=xcrun --sdk $$(SDK-$1) clang \
	-arch $$(ARCH-$1) \
	--sysroot=$$(SDK_ROOT-$1) \
	$$(CFLAGS-$2) $$(CFLAGS-$1)
LDFLAGS-$1=-arch $$(ARCH-$1) -isysroot=$$(SDK_ROOT-$1)

OPENSSL_DIR-$1=build/$2/openssl-$(OPENSSL_VERSION)-$1
BZIP2_DIR-$1=build/$2/bzip2-$(BZIP2_VERSION)-$1
XZ_DIR-$1=build/$2/xz-$(XZ_VERSION)-$1
PYTHON_DIR-$1=build/$2/Python-$(PYTHON_VERSION)-$1
pyconfig.h-$1=pyconfig-$$(ARCH-$1).h

ifeq ($2,macOS)
PYTHON_HOST_DEP-$1=
else
PYTHON_HOST-$1=$(PYTHON_HOST)
endif

# Unpack OpenSSL
$$(OPENSSL_DIR-$1)/Makefile: downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	mkdir -p $$(OPENSSL_DIR-$1)
	tar zxf downloads/openssl-$(OPENSSL_VERSION).tgz --strip-components 1 -C $$(OPENSSL_DIR-$1)
ifeq ($$(findstring simulator,$$(SDK-$1)),)
	# Tweak ui_openssl.c
	sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" $$(OPENSSL_DIR-$1)/crypto/ui/ui_openssl.c
endif
ifeq ($$(findstring iphone,$$(SDK-$1)),)
	# Patch apps/speed.c and apps/ocsp.c to not use fork() since it's not available on tvOS
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_DIR-$1)/apps/speed.c
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_DIR-$1)/apps/ocsp.c
	# Patch Configure to build for tvOS or watchOS, not iOS
	LC_ALL=C sed -ie 's/-D_REENTRANT:iOS/-D_REENTRANT:$2/' $$(OPENSSL_DIR-$1)/Configure
endif

	# Configure the build
ifeq ($2,macOS)
	cd $$(OPENSSL_DIR-$1) && \
	CC="$$(CC-$1)" MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) \
		./Configure darwin64-x86_64-cc no-tests --prefix=$(PROJECT_DIR)/build/$2/openssl --openssldir=$(PROJECT_DIR)/build/$2/openssl
else
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		./Configure iphoneos-cross no-asm no-tests --prefix=$(PROJECT_DIR)/build/$2/openssl --openssldir=$(PROJECT_DIR)/build/$2/openssl
endif

# Build OpenSSL
$$(OPENSSL_DIR-$1)/libssl.a $$(OPENSSL_DIR-$1)/libcrypto.a: $$(OPENSSL_DIR-$1)/Makefile
	# Make the build, and install just the software (not the docs)
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		make all && make install_sw

# Unpack BZip2
$$(BZIP2_DIR-$1)/Makefile: downloads/bzip2-$(BZIP2_VERSION).tgz
	# Unpack sources
	mkdir -p $$(BZIP2_DIR-$1)
	tar zxf downloads/bzip2-$(BZIP2_VERSION).tgz --strip-components 1 -C $$(BZIP2_DIR-$1)
	# Patch sources to use correct compiler
	sed -ie 's#CC=gcc#CC=$$(CC-$1)#' $$(BZIP2_DIR-$1)/Makefile
	# Patch sources to use correct install directory
	sed -ie 's#PREFIX=/usr/local#PREFIX=$(PROJECT_DIR)/build/$2/bzip2#' $$(BZIP2_DIR-$1)/Makefile

# Build BZip2
$$(BZIP2_DIR-$1)/libbz2.a: $$(BZIP2_DIR-$1)/Makefile
	cd $$(BZIP2_DIR-$1) && make install

# Unpack XZ
$$(XZ_DIR-$1)/Makefile: downloads/xz-$(XZ_VERSION).tgz
	# Unpack sources
	mkdir -p $$(XZ_DIR-$1)
	tar zxf downloads/xz-$(XZ_VERSION).tgz --strip-components 1 -C $$(XZ_DIR-$1)
	# Configure the build
	cd $$(XZ_DIR-$1) && MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) ./configure \
		CC="$$(CC-$1)" \
		LDFLAGS="$$(LDFLAGS-$1)" \
		--disable-shared --enable-static \
		--host=$$(MACHINE_SIMPLE-$1)-apple-darwin \
		--prefix=$(PROJECT_DIR)/build/$2/xz

# Build XZ
$$(XZ_DIR-$1)/src/liblzma/.libs/liblzma.a: $$(XZ_DIR-$1)/Makefile
	cd $$(XZ_DIR-$1) && make && make install

# Unpack Python
$$(PYTHON_DIR-$1)/Makefile: downloads/Python-$(PYTHON_VERSION).tgz $$(PYTHON_HOST-$1)
	# Unpack target Python
	mkdir -p $$(PYTHON_DIR-$1)
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$1)
	# Apply target Python patches
	cd $$(PYTHON_DIR-$1) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Configure target Python
ifeq ($2,macOS)
	# A locally hosted Python requires a full Setup.local configuration
	# because there's no PYTHON_HOST_PLATFORM to cause Setup.local to be
	# generated
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded $(PROJECT_DIR)/patch/Python/Setup.macOS-x86_64 > $$(PYTHON_DIR-$1)/Modules/Setup.local
	# Make a fully embedded macOS build
	cd $$(PYTHON_DIR-$1) && MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) ./configure \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$1)/dist \
		--without-doc-strings --enable-ipv6 --without-ensurepip \
		$$(PYTHON_CONFIGURE-$2)
else
	# Copy in the embedded and platform/arch configuration
	cp -f $(PROJECT_DIR)/patch/Python/Setup.embedded $$(PYTHON_DIR-$1)/Modules/Setup.embedded
	if [ -e "$(PROJECT_DIR)/patch/Python/Setup.$2-$$(ARCH-$1)" ]; then \
		cp -f $(PROJECT_DIR)/patch/Python/Setup.$2-$$(ARCH-$1) $$(PYTHON_DIR-$1)/Modules/Setup.$2-$$(ARCH-$1); fi
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH) ./configure \
		CC="$$(CC-$1)" LD="$$(CC-$1)" \
		--host=$$(MACHINE_DETAILED-$1)-apple-$(shell echo $2 | tr '[:upper:]' '[:lower:]') \
		--build=x86_64-apple-darwin$(shell uname -r) \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$1)/dist \
		--without-doc-strings --enable-ipv6 --without-ensurepip \
		ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
		$$(PYTHON_CONFIGURE-$2)
endif

# Build Python
$$(PYTHON_DIR-$1)/dist/lib/libpython$(PYTHON_VER).a: build/$2/Support/OpenSSL build/$2/Support/BZip2 build/$2/Support/XZ $$(PYTHON_DIR-$1)/Makefile
	# Build target Python
	cd $$(PYTHON_DIR-$1) && PATH="$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH)" make all install

build/$2/$$(pyconfig.h-$1): $$(PYTHON_DIR-$1)/dist/include/python$(PYTHON_VER)/pyconfig.h
	cp -f $$^ $$@

# Dump vars (for test)
vars-$1:
	@echo "ARCH-$1: $$(ARCH-$1)"
	@echo "MACHINE_DETAILED-$1: $$(MACHINE_DETAILED-$1)"
	@echo "SDK-$1: $$(SDK-$1)"
	@echo "SDK_ROOT-$1: $$(SDK_ROOT-$1)"
	@echo "CC-$1: $$(CC-$1)"
endef

#
# Build for specified OS (from $(OS))
# Parameters:
# - $1 - OS
define build
$$(foreach target,$$(TARGETS-$1),$$(eval $$(call build-target,$$(target),$1)))

OPENSSL_FRAMEWORK-$1=build/$1/Support/OpenSSL
BZIP2_FRAMEWORK-$1=build/$1/Support/BZip2
XZ_FRAMEWORK-$1=build/$1/Support/XZ
PYTHON_FRAMEWORK-$1=build/$1/Support/Python
PYTHON_RESOURCES-$1=$$(PYTHON_FRAMEWORK-$1)/Resources

$1: dist/Python-$(PYTHON_VER)-$1-support.$(BUILD_NUMBER).tar.gz

clean-$1:
	rm -rf build/$1

dist/Python-$(PYTHON_VER)-$1-support.$(BUILD_NUMBER).tar.gz: $$(BZIP2_FRAMEWORK-$1) $$(XZ_FRAMEWORK-$1) $$(OPENSSL_FRAMEWORK-$1) $$(PYTHON_FRAMEWORK-$1)
	mkdir -p dist
	echo "Python version: $(PYTHON_VERSION) " > build/$1/Support/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> build/$1/Support/VERSIONS
	echo "---------------------" >> build/$1/Support/VERSIONS
	echo "BZip2: $(BZIP2_VERSION)" >> build/$1/Support/VERSIONS
	echo "OpenSSL: $(OPENSSL_VERSION)" >> build/$1/Support/VERSIONS
	echo "XZ: $(XZ_VERSION)" >> build/$1/Support/VERSIONS

	# Build a "full" tarball with all content for test purposes
	tar zcvf dist/Python-$(PYTHON_VER)-$1-support.test-$(BUILD_NUMBER).tar.gz -X patch/Python/test-exclude.embedded -C build/$1/Support `ls -A build/$1/Support`
	# Build a distributable tarball
	tar zcvf $$@ -X patch/Python/exclude.embedded -C build/$1/Support `ls -A build/$1/Support`

# Build OpenSSL
OpenSSL-$1: $$(OPENSSL_FRAMEWORK-$1)

$$(OPENSSL_FRAMEWORK-$1): build/$1/libssl.a build/$1/libcrypto.a
	# Create framework directory structure
	mkdir -p $$(OPENSSL_FRAMEWORK-$1)

	# Copy the headers
	cp -f -r $$(OPENSSL_DIR-$$(firstword $$(TARGETS-$1)))/include $$(OPENSSL_FRAMEWORK-$1)/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(OPENSSL_FRAMEWORK-$1)/libOpenSSL.a $$^


build/$1/libssl.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libssl.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

build/$1/libcrypto.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libcrypto.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

# Build BZip2
BZip2-$1: $$(BZIP2_FRAMEWORK-$1)

$$(BZIP2_FRAMEWORK-$1): build/$1/bzip2/lib/libbz2.a
	# Create framework directory structure
	mkdir -p $$(BZIP2_FRAMEWORK-$1)

	# Copy the headers
	cp -f -r build/$1/bzip2/include $$(BZIP2_FRAMEWORK-$1)/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(BZIP2_FRAMEWORK-$1)/libbzip2.a $$^


build/$1/bzip2/lib/libbz2.a: $$(foreach target,$$(TARGETS-$1),$$(BZIP2_DIR-$$(target))/libbz2.a)
	mkdir -p build/$1
	xcrun lipo -create -o $$@ $$^

# Build XZ
XZ-$1: $$(XZ_FRAMEWORK-$1)

$$(XZ_FRAMEWORK-$1): build/$1/xz/lib/liblzma.a
	# Create framework directory structure
	mkdir -p $$(XZ_FRAMEWORK-$1)

	# Copy the headers
	cp -f -r build/$1/xz/include $$(XZ_FRAMEWORK-$1)/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(XZ_FRAMEWORK-$1)/libxz.a $$^

build/$1/xz/lib/liblzma.a: $$(foreach target,$$(TARGETS-$1),$$(XZ_DIR-$$(target))/src/liblzma/.libs/liblzma.a)
	mkdir -p build/$1
	xcrun lipo -create -o $$@ $$^

$1: Python-$1

Python-$1: dist/Python-$(PYTHON_VER)-$1-support.$(BUILD_NUMBER).tar.gz

# Build Python
$$(PYTHON_FRAMEWORK-$1): build/$1/libpython$(PYTHON_VER).a $$(foreach target,$$(TARGETS-$1),build/$1/$$(pyconfig.h-$$(target)))
	mkdir -p $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)

	# Copy the headers. The headers are the same for every platform, except for pyconfig.h
	# We ship a master pyconfig.h for iOS, tvOS and watchOS that delegates to architecture
	# specific versions; on macOS, we can use the original version as-is.
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/dist/include/python$(PYTHON_VER) $$(PYTHON_FRAMEWORK-$1)/Headers
	cp -f $$(filter %.h,$$^) $$(PYTHON_FRAMEWORK-$1)/Headers
ifeq ($1,macOS)
	mv $$(PYTHON_FRAMEWORK-$1)/Headers/pyconfig-x86_64.h $$(PYTHON_FRAMEWORK-$1)/Headers/pyconfig.h
else
	cp -f $(PROJECT_DIR)/patch/Python/pyconfig-$1.h $$(PYTHON_FRAMEWORK-$1)/Headers/pyconfig.h
endif
	# Copy Python.h and pyconfig.h into the resources include directory
	cp -f -r $$(PYTHON_FRAMEWORK-$1)/Headers/pyconfig*.h $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)
	cp -f -r $$(PYTHON_FRAMEWORK-$1)/Headers/Python.h $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)

	# Copy the standard library from the simulator build
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/dist/lib $$(PYTHON_RESOURCES-$1)

	# Copy fat library
	cp -f $$(filter %.a,$$^) $$(PYTHON_FRAMEWORK-$1)/libPython.a


# Build libpython fat library
build/$1/libpython$(PYTHON_VER).a: $$(foreach target,$$(TARGETS-$1),$$(PYTHON_DIR-$$(target))/dist/lib/libpython$(PYTHON_VER).a)
	# Create a fat binary for the libPython library
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

vars-$1: $$(foreach target,$$(TARGETS-$1),vars-$$(target))

endef

$(foreach os,$(OS),$(eval $(call build,$(os))))

###########################################################################
# Compiling Python Libraries with binary components
###########################################################################

HOST_PYTHON=$(CURDIR)/build/macOS/python/bin/python3
HOST_PIP=$(CURDIR)/build/macOS/python/bin/pip3

# Ensure pip and setuptools are available
pip: Python-macOS
	$(HOST_PYTHON) -m ensurepip

# Create the directory that will contain installed packages
dist/app_packages:
	mkdir -p dist/app_packages

# Makefiles for individual binary packages that are supported.
include patch/numpy/Makefile.numpy

define build-app-packages
packages-$1: numpy-$1
endef

$(foreach os,$(OS),$(eval $(call build-app-packages,$(os))))

app_packages: numpy

# Dump vars (for test)
vars: $(foreach os,$(OS),vars-$(os))
	@echo "APP_PACKAGES: $(APP_PACKAGES)"
