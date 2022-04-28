#
# Useful targets:
# - all             - build everything
# - macOS           - build everything for macOS
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS
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
# - libFFI-iOS      - build libFFI for iOS
# - libFFI-tvOS     - build libFFI for tvOS
# - libFFI-watchOS  - build libFFI for watchOS
# - Python-macOS    - build Python for macOS
# - Python-iOS      - build Python for iOS
# - Python-tvOS     - build Python for tvOS
# - Python-watchOS  - build Python for watchOS

# Current director
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=custom

MACOSX_DEPLOYMENT_TARGET=10.8

# Version of packages that will be compiled by this meta-package
# PYTHON_VERSION is the full version number (e.g., 3.10.0b3)
# PYTHON_MICRO_VERSION is the full version number, without any alpha/beta/rc suffix. (e.g., 3.10.0)
# PYTHON_VER is the major/minor version (e.g., 3.10)
PYTHON_VERSION=3.10.4
PYTHON_MICRO_VERSION=$(shell echo $(PYTHON_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_VER=$(basename $(PYTHON_VERSION))

OPENSSL_VERSION_NUMBER=1.1.1
OPENSSL_REVISION=n
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

BZIP2_VERSION=1.0.8

XZ_VERSION=5.2.5

LIBFFI_VERSION=3.4.2

# Supported OS
OS=macOS iOS tvOS watchOS

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
PYTHON_TARGETS-macOS=macOS
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

downloads: downloads/openssl-$(OPENSSL_VERSION).tgz downloads/bzip2-$(BZIP2_VERSION).tgz downloads/xz-$(XZ_VERSION).tgz downloads/libffi-$(LIBFFI_VERSION).tgz downloads/Python-$(PYTHON_VERSION).tgz

update-patch:
	# Generate a diff from the clone of the python/cpython Github repository
	# Requireds patchutils (installable via `brew install patchutils`)
	if [ -z "$(PYTHON_REPO_DIR)" ]; then echo "\n\nPYTHON_REPO_DIR must be set to the root of your Python github checkout\n\n"; fi
	cd $(PYTHON_REPO_DIR) && git diff -D v$(PYTHON_VERSION) $(PYTHON_VER) | filterdiff -X $(PROJECT_DIR)/patch/Python/diff.exclude -p 1 --clean > $(PROJECT_DIR)/patch/Python/Python.patch

###########################################################################
# OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	rm -rf build/*/openssl-$(OPENSSL_VERSION)-* \
		build/*/openssl \
		build/*/libssl.a build/*/libcrypto.a \
		build/*/Support/OpenSSL

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	mkdir -p downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi


###########################################################################
# BZip2
###########################################################################

# Clean the bzip2 project
clean-BZip2:
	rm -rf build/*/bzip2-$(BZIP2_VERSION)-* \
		build/*/bzip2 \
		build/*/Support/BZip2

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/bzip2-$(BZIP2_VERSION).tgz ]; then curl --fail -L https://sourceware.org/pub/bzip2/bzip2-$(BZIP2_VERSION).tar.gz -o downloads/bzip2-$(BZIP2_VERSION).tgz; fi

###########################################################################
# XZ (LZMA)
###########################################################################

# Clean the XZ project
clean-XZ:
	rm -rf build/*/xz-$(XZ_VERSION)-* \
		build/*/xz \
		build/*/Support/XZ

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/xz-$(XZ_VERSION).tgz ]; then curl --fail -L http://tukaani.org/xz/xz-$(XZ_VERSION).tar.gz -o downloads/xz-$(XZ_VERSION).tgz; fi

###########################################################################
# LIBFFI
###########################################################################

# Clean the LibFFI project
clean-libFFI:
	rm -rf build/*/libffi-$(LIBFFI_VERSION) \
		build/*/Support/libFFI

# Download original XZ source code archive.
downloads/libffi-$(LIBFFI_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/libffi-$(LIBFFI_VERSION).tgz ]; then curl --fail -L http://github.com/libffi/libffi/releases/download/v$(LIBFFI_VERSION)/libffi-$(LIBFFI_VERSION).tar.gz -o downloads/libffi-$(LIBFFI_VERSION).tgz; fi

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf \
		build/*/Python-$(PYTHON_VERSION)-* \
		build/*/libpython$(PYTHON_VER).a \
		build/*/pyconfig-*.h \
		build/*/Support/Python

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_MICRO_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

# Some Python targets needed to identify the host build
PYTHON_DIR-macOS=build/macOS/Python-$(PYTHON_VERSION)-macOS
PYTHON_HOST=$(PYTHON_DIR-macOS)/dist/lib/libpython$(PYTHON_VER).a

# Build for specified target (from $(TARGETS))
#
# Parameters:
# - $1 - target
# - $2 - OS
define build-target
target=$1
os=$2

ARCH-$(target)=$$(subst .,,$$(suffix $(target)))
ifdef MACHINE_DETAILED-$$(ARCH-$(target))
MACHINE_DETAILED-$(target)=$$(MACHINE_DETAILED-$$(ARCH-$(target)))
else
MACHINE_DETAILED-$(target)=$$(ARCH-$(target))
endif
ifdef MACHINE_SIMPLE-$$(ARCH-$(target))
MACHINE_SIMPLE-$(target)=$$(MACHINE_SIMPLE-$$(ARCH-$(target)))
else
MACHINE_SIMPLE-$(target)=$$(ARCH-$(target))
endif
SDK-$(target)=$$(basename $(target))

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang \
	-arch $$(ARCH-$(target)) \
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os)) $$(CFLAGS-$(target))
LDFLAGS-$(target)=-arch $$(ARCH-$(target)) -isysroot=$$(SDK_ROOT-$(target))

OPENSSL_DIR-$(target)=build/$(os)/openssl-$(OPENSSL_VERSION)-$(target)
BZIP2_DIR-$(target)=build/$(os)/bzip2-$(BZIP2_VERSION)-$(target)
XZ_DIR-$(target)=build/$(os)/xz-$(XZ_VERSION)-$(target)
LIBFFI_DIR-$(target)=build/$(os)/libffi-$(LIBFFI_VERSION)

# Unpack OpenSSL
$$(OPENSSL_DIR-$(target))/Makefile: downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	mkdir -p $$(OPENSSL_DIR-$(target))
	tar zxf downloads/openssl-$(OPENSSL_VERSION).tgz --strip-components 1 -C $$(OPENSSL_DIR-$(target))
ifeq ($$(findstring simulator,$$(SDK-$(target))),)
	# Tweak ui_openssl.c
	sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" $$(OPENSSL_DIR-$(target))/crypto/ui/ui_openssl.c
endif
ifeq ($$(findstring iphone,$$(SDK-$(target))),)
	# Patch apps/speed.c and apps/ocsp.c to not use fork() since it's not available on tvOS
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_DIR-$(target))/apps/speed.c
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_DIR-$(target))/apps/ocsp.c
	# Patch Configure to build for tvOS or watchOS, not iOS
	LC_ALL=C sed -ie 's/-D_REENTRANT:iOS/-D_REENTRANT:$(os)/' $$(OPENSSL_DIR-$(target))/Configure
endif

	# Configure the build
ifeq ($(os),macOS)
	cd $$(OPENSSL_DIR-$(target)) && \
	CC="$$(CC-$(target))" MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) \
		./Configure darwin64-$$(ARCH-$(target))-cc no-tests --prefix=$(PROJECT_DIR)/build/$(os)/openssl --openssldir=/etc/ssl
else
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		./Configure iphoneos-cross no-asm no-tests --prefix=$(PROJECT_DIR)/build/$(os)/openssl --openssldir=/etc/ssl
endif

# Build OpenSSL
$$(OPENSSL_DIR-$(target))/libssl.a $$(OPENSSL_DIR-$(target))/libcrypto.a: $$(OPENSSL_DIR-$(target))/Makefile
	# Make the build, and install just the software (not the docs)
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make all && make install_sw

# Unpack BZip2
$$(BZIP2_DIR-$(target))/Makefile: downloads/bzip2-$(BZIP2_VERSION).tgz
	# Unpack sources
	mkdir -p $$(BZIP2_DIR-$(target))
	tar zxf downloads/bzip2-$(BZIP2_VERSION).tgz --strip-components 1 -C $$(BZIP2_DIR-$(target))
	# Patch sources to use correct compiler
	sed -ie 's#CC=gcc#CC=$$(CC-$(target))#' $$(BZIP2_DIR-$(target))/Makefile
	# Patch sources to use correct install directory
	sed -ie 's#PREFIX=/usr/local#PREFIX=$(PROJECT_DIR)/build/$(os)/bzip2#' $$(BZIP2_DIR-$(target))/Makefile

# Build BZip2
$$(BZIP2_DIR-$(target))/libbz2.a: $$(BZIP2_DIR-$(target))/Makefile
	cd $$(BZIP2_DIR-$(target)) && make install

# Unpack XZ
$$(XZ_DIR-$(target))/Makefile: downloads/xz-$(XZ_VERSION).tgz
	# Unpack sources
	mkdir -p $$(XZ_DIR-$(target))
	tar zxf downloads/xz-$(XZ_VERSION).tgz --strip-components 1 -C $$(XZ_DIR-$(target))
	# Configure the build
	cd $$(XZ_DIR-$(target)) && MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) ./configure \
		CC="$$(CC-$(target))" \
		LDFLAGS="$$(LDFLAGS-$(target))" \
		--disable-shared --enable-static \
		--host=$$(MACHINE_SIMPLE-$(target))-apple-darwin \
		--prefix=$(PROJECT_DIR)/build/$(os)/xz

# Build XZ
$$(XZ_DIR-$(target))/src/liblzma/.libs/liblzma.a: $$(XZ_DIR-$(target))/Makefile
	cd $$(XZ_DIR-$(target)) && make && make install

# macOS builds use their own libFFI, and are compiled as a single
# universal2 build. As a result, the macOS Python build is configured
# in the `build` macro, rather than the `build-target` macro.
ifneq ($(os),macOS)
LIBFFI_BUILD_DIR-$(target)=build_$$(SDK-$(target))-$$(ARCH-$(target))
PYTHON_DIR-$(target)=build/$(os)/Python-$(PYTHON_VERSION)-$(target)
pyconfig.h-$(target)=pyconfig-$$(ARCH-$(target)).h
PYTHON_HOST-$(target)=$(PYTHON_HOST)

# Build LibFFI
$$(LIBFFI_DIR-$(target))/libffi.$(target).a: $$(LIBFFI_DIR-$(target))/darwin_common
	cd $$(LIBFFI_DIR-$(target))/$$(LIBFFI_BUILD_DIR-$(target)) && make

	# Copy in the lib to a non-BUILD_DIR dependent location;
	# include the target in the final filename for disambiguation
	cp $$(LIBFFI_DIR-$(target))/$$(LIBFFI_BUILD_DIR-$(target))/.libs/libffi.a $$(LIBFFI_DIR-$(target))/libffi.$(target).a

# Unpack Python
$$(PYTHON_DIR-$(target))/Makefile: downloads/Python-$(PYTHON_VERSION).tgz $$(PYTHON_HOST-$(target))
	# Unpack target Python
	mkdir -p $$(PYTHON_DIR-$(target))
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$(target))
	# Apply target Python patches
	cd $$(PYTHON_DIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Copy in the embedded module configuration
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded $(PROJECT_DIR)/patch/Python/Setup.$(os) > $$(PYTHON_DIR-$(target))/Modules/Setup.local
	# Configure target Python
	cd $$(PYTHON_DIR-$(target)) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH) ./configure \
		CC="$$(CC-$(target))" LD="$$(CC-$(target))" \
		--host=$$(MACHINE_DETAILED-$(target))-apple-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') \
		--build=x86_64-apple-darwin \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$(target))/dist \
		--without-doc-strings --enable-ipv6 --without-ensurepip \
		ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
		$$(PYTHON_CONFIGURE-$(os))

# Build Python
$$(PYTHON_DIR-$(target))/dist/lib/libpython$(PYTHON_VER).a: build/$(os)/Support/OpenSSL build/$(os)/Support/BZip2 build/$(os)/Support/XZ build/$(os)/Support/libFFI $$(PYTHON_DIR-$(target))/Makefile
	# Build target Python
	cd $$(PYTHON_DIR-$(target)) && PATH="$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH)" make all install

build/$(os)/$$(pyconfig.h-$(target)): $$(PYTHON_DIR-$(target))/dist/include/python$(PYTHON_VER)/pyconfig.h
	cp -f $$^ $$@

endif

# Dump vars (for test)
vars-$(target):
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "MACHINE_DETAILED-$(target): $$(MACHINE_DETAILED-$(target))"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CC-$(target): $$(CC-$(target))"
	@echo "LIBFFI_BUILD_DIR-$(target): $$(LIBFFI_BUILD_DIR-$(target))"
	@echo "OPENSSL_DIR-$(target): $$(OPENSSL_DIR-$(target))"
	@echo "BZIP2_DIR-$(target): $$(BZIP2_DIR-$(target))"
	@echo "XZ_DIR-$(target): $$(XZ_DIR-$(target))"
	@echo "LIBFFI_DIR-$(target): $$(LIBFFI_DIR-$(target))"
	@echo "PYTHON_DIR-$(target): $$(PYTHON_DIR-$(target))"
	@echo "pyconfig.h-$(target): $$(pyconfig.h-$(target))"

endef

#
# Build for specified OS (from $(OS))
# Parameters:
# - $(target) - OS
define build
os=$(target)

$$(foreach target,$$(TARGETS-$(os)),$$(eval $$(call build-target,$$(target),$(os))))

OPENSSL_FRAMEWORK-$(os)=build/$(os)/Support/OpenSSL
BZIP2_FRAMEWORK-$(os)=build/$(os)/Support/BZip2
XZ_FRAMEWORK-$(os)=build/$(os)/Support/XZ
LIBFFI_FRAMEWORK-$(os)=build/$(os)/Support/libFFI
PYTHON_FRAMEWORK-$(os)=build/$(os)/Support/Python
PYTHON_RESOURCES-$(os)=$$(PYTHON_FRAMEWORK-$(os))/Resources

$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

clean-$(os):
	rm -rf build/$(os)

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: $$(BZIP2_FRAMEWORK-$(os)) $$(XZ_FRAMEWORK-$(os)) $$(OPENSSL_FRAMEWORK-$(os)) $$(LIBFFI_FRAMEWORK-$(os)) $$(PYTHON_FRAMEWORK-$(os))
	mkdir -p dist
	echo "Python version: $(PYTHON_VERSION) " > build/$(os)/Support/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> build/$(os)/Support/VERSIONS
	echo "---------------------" >> build/$(os)/Support/VERSIONS
ifeq ($(os),macOS)
	echo "libFFI: macOS native" >> build/$(os)/Support/VERSIONS
else
	echo "libFFI: $(LIBFFI_VERSION)" >> build/$(os)/Support/VERSIONS
endif
	echo "BZip2: $(BZIP2_VERSION)" >> build/$(os)/Support/VERSIONS
	echo "OpenSSL: $(OPENSSL_VERSION)" >> build/$(os)/Support/VERSIONS
	echo "XZ: $(XZ_VERSION)" >> build/$(os)/Support/VERSIONS

	# Build a "full" tarball with all content for test purposes
	tar zcvf dist/Python-$(PYTHON_VER)-$(os)-support.test-$(BUILD_NUMBER).tar.gz -X patch/Python/test.exclude -C build/$(os)/Support `ls -A build/$(os)/Support`
	# Build a distributable tarball
	tar zcvf $$@ -X patch/Python/release.common.exclude -X patch/Python/release.$(os).exclude -C build/$(os)/Support `ls -A build/$(os)/Support`

# Build OpenSSL
OpenSSL-$(os): $$(OPENSSL_FRAMEWORK-$(os))

$$(OPENSSL_FRAMEWORK-$(os)): build/$(os)/libssl.a build/$(os)/libcrypto.a
	# Create framework directory structure
	mkdir -p $$(OPENSSL_FRAMEWORK-$(os))

	# Copy the headers
	cp -f -r $$(OPENSSL_DIR-$$(firstword $$(TARGETS-$(os))))/include $$(OPENSSL_FRAMEWORK-$(os))/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(OPENSSL_FRAMEWORK-$(os))/libOpenSSL.a $$^


build/$(os)/libssl.a: $$(foreach target,$$(TARGETS-$(os)),$$(OPENSSL_DIR-$$(target))/libssl.a)
	mkdir -p build/$(os)
	xcrun lipo -create -output $$@ $$^

build/$(os)/libcrypto.a: $$(foreach target,$$(TARGETS-$(os)),$$(OPENSSL_DIR-$$(target))/libcrypto.a)
	mkdir -p build/$(os)
	xcrun lipo -create -output $$@ $$^

# Build BZip2
BZip2-$(os): $$(BZIP2_FRAMEWORK-$(os))

$$(BZIP2_FRAMEWORK-$(os)): build/$(os)/bzip2/lib/libbz2.a
	# Create framework directory structure
	mkdir -p $$(BZIP2_FRAMEWORK-$(os))

	# Copy the headers
	cp -f -r build/$(os)/bzip2/include $$(BZIP2_FRAMEWORK-$(os))/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(BZIP2_FRAMEWORK-$(os))/libbzip2.a $$^


build/$(os)/bzip2/lib/libbz2.a: $$(foreach target,$$(TARGETS-$(os)),$$(BZIP2_DIR-$$(target))/libbz2.a)
	mkdir -p build/$(os)
	xcrun lipo -create -o $$@ $$^

# Build XZ
XZ-$(os): $$(XZ_FRAMEWORK-$(os))

$$(XZ_FRAMEWORK-$(os)): build/$(os)/xz/lib/liblzma.a
	# Create framework directory structure
	mkdir -p $$(XZ_FRAMEWORK-$(os))

	# Copy the headers
	cp -f -r build/$(os)/xz/include $$(XZ_FRAMEWORK-$(os))/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(XZ_FRAMEWORK-$(os))/libxz.a $$^

build/$(os)/xz/lib/liblzma.a: $$(foreach target,$$(TARGETS-$(os)),$$(XZ_DIR-$$(target))/src/liblzma/.libs/liblzma.a)
	mkdir -p build/$(os)
	xcrun lipo -create -o $$@ $$^

# Build libFFI
libFFI-$(os): $$(LIBFFI_FRAMEWORK-$(os))

# macOS builds a single Python universal2 target; thus it needs to be
# configured in the `build` macro, not the `build-target` macro.
# macOS also uses the system-provided libFFI, so there's no need to package
# a libFFI framework for macOS.
ifeq ($(os),macOS)
# Some targets that are needed for consistency between macOS and other builds,
# but are no-ops on macOS.
$$(LIBFFI_FRAMEWORK-$(os)):

build/$(os)/$$(pyconfig.h-$(os)):

# Unpack Python
$$(PYTHON_DIR-$(os))/Makefile: downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack target Python
	mkdir -p $$(PYTHON_DIR-$(os))
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$(os))
	# Apply target Python patches
	cd $$(PYTHON_DIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Copy in the embedded module configuration
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded $(PROJECT_DIR)/patch/Python/Setup.$(os) > $$(PYTHON_DIR-$(os))/Modules/Setup.local
	# Configure target Python
	cd $$(PYTHON_DIR-$(os)) && MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET) ./configure \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$(os))/dist \
		--without-doc-strings --enable-ipv6 --without-ensurepip --enable-universalsdk --with-universal-archs=universal2 \
		$$(PYTHON_CONFIGURE-$(os))

# Build Python
$$(PYTHON_DIR-$(os))/dist/lib/libpython$(PYTHON_VER).a: build/$(os)/Support/OpenSSL build/$(os)/Support/BZip2 build/$(os)/Support/XZ build/$(os)/Support/libFFI $$(PYTHON_DIR-$(os))/Makefile
	# Build target Python
	cd $$(PYTHON_DIR-$(os)) && PATH="$(PROJECT_DIR)/$(PYTHON_DIR-$(os))/dist/bin:$(PATH)" make all install

else
# The LibFFI folder is shared between all architectures for the OS
LIBFFI_DIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)
# The Python targets are the same as they are for every other library
PYTHON_TARGETS-$(os)=$$(TARGETS-$(os))

# Unpack LibFFI and generate source & headers
$$(LIBFFI_DIR-$(os))/darwin_common: downloads/libffi-$(LIBFFI_VERSION).tgz
	# Unpack sources
	mkdir -p $$(LIBFFI_DIR-$(os))
	tar zxf downloads/libffi-$(LIBFFI_VERSION).tgz --strip-components 1 -C $$(LIBFFI_DIR-$(os))
	# Configure the build
	cd $$(LIBFFI_DIR-$(os)) && python generate-darwin-source-and-headers.py --only-$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

$$(LIBFFI_FRAMEWORK-$(os)): $$(LIBFFI_DIR-$(os))/libffi.a
	# Create framework directory structure
	mkdir -p $$(LIBFFI_FRAMEWORK-$(os))

	# Copy the headers.
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_common/include $$(LIBFFI_FRAMEWORK-$(os))/Headers
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_$(shell echo $(os) | tr '[:upper:]' '[:lower:]')/include/* $$(LIBFFI_FRAMEWORK-$(os))/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(LIBFFI_FRAMEWORK-$(os))/libFFI.a $$^

$$(LIBFFI_DIR-$(os))/libffi.a: $$(foreach target,$$(TARGETS-$(os)),$$(LIBFFI_DIR-$(os))/libffi.$$(target).a)
	xcrun lipo -create -o $$@ $$^

endif

$(os): Python-$(os)

Python-$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

# Build Python
$$(PYTHON_FRAMEWORK-$(os)): build/$(os)/libpython$(PYTHON_VER).a $$(foreach target,$$(PYTHON_TARGETS-$(os)),build/$(os)/$$(pyconfig.h-$$(target)))
	mkdir -p $$(PYTHON_RESOURCES-$(os))/include/python$(PYTHON_VER)

	# Copy the headers. The headers are the same for every platform, except for pyconfig.h
	# We ship a master pyconfig.h for iOS, tvOS and watchOS that delegates to architecture
	# specific versions; on macOS, we can use the original version as-is.
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(PYTHON_TARGETS-$(os))))/dist/include/python$(PYTHON_VER) $$(PYTHON_FRAMEWORK-$(os))/Headers
ifneq ($(os),macOS)
	cp -f $$(filter %.h,$$^) $$(PYTHON_FRAMEWORK-$(os))/Headers
	cp -f $(PROJECT_DIR)/patch/Python/pyconfig-$(os).h $$(PYTHON_FRAMEWORK-$(os))/Headers/pyconfig.h
endif
	# Copy Python.h and pyconfig.h into the resources include directory
	cp -f -r $$(PYTHON_FRAMEWORK-$(os))/Headers/pyconfig*.h $$(PYTHON_RESOURCES-$(os))/include/python$(PYTHON_VER)
	cp -f -r $$(PYTHON_FRAMEWORK-$(os))/Headers/Python.h $$(PYTHON_RESOURCES-$(os))/include/python$(PYTHON_VER)

	# Copy the standard library from the simulator build
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(PYTHON_TARGETS-$(os))))/dist/lib $$(PYTHON_RESOURCES-$(os))

	# Copy fat library
	cp -f $$(filter %.a,$$^) $$(PYTHON_FRAMEWORK-$(os))/libPython.a


# Build libpython fat library
build/$(os)/libpython$(PYTHON_VER).a: $$(foreach target,$$(PYTHON_TARGETS-$(os)),$$(PYTHON_DIR-$$(target))/dist/lib/libpython$(PYTHON_VER).a)
	# Create a fat binary for the libPython library
	mkdir -p build/$(os)
	xcrun lipo -create -output $$@ $$^

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target))
	@echo "OPENSSL_FRAMEWORK-$(os): $$(OPENSSL_FRAMEWORK-$(os))"
	@echo "BZIP2_FRAMEWORK-$(os): $$(BZIP2_FRAMEWORK-$(os))"
	@echo "XZ_FRAMEWORK-$(os): $$(XZ_FRAMEWORK-$(os))"
	@echo "LIBFFI_FRAMEWORK-$(os): $$(LIBFFI_FRAMEWORK-$(os))"
	@echo "PYTHON_FRAMEWORK-$(os): $$(PYTHON_FRAMEWORK-$(os))"
	@echo "LIBFFI_DIR-$(os): $$(LIBFFI_DIR-$(os))"
	@echo "PYTHON_RESOURCES-$(os): $$(PYTHON_RESOURCES-$(os))"
	@echo "PYTHON_TARGETS-$(os): $$(PYTHON_TARGETS-$(os))"

endef

$(foreach os,$(OS),$(eval $(call build,$(os))))
