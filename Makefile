#
# Useful targets:
# - all             - build everything
# - macOS           - build everything for macOS
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS
# - BZip2           - build BZip2 for all platforms
# - BZip2-macOS     - build BZip2 for macOS
# - BZip2-iOS       - build BZip2 for iOS
# - BZip2-tvOS      - build BZip2 for tvOS
# - BZip2-watchOS   - build BZip2 for watchOS
# - XZ              - build XZ for all platforms
# - XZ-macOS        - build XZ for macOS
# - XZ-iOS          - build XZ for iOS
# - XZ-tvOS         - build XZ for tvOS
# - XZ-watchOS      - build XZ for watchOS
# - OpenSSL         - build OpenSSL for all platforms
# - OpenSSL-macOS   - build OpenSSL for macOS
# - OpenSSL-iOS     - build OpenSSL for iOS
# - OpenSSL-tvOS    - build OpenSSL for tvOS
# - OpenSSL-watchOS - build OpenSSL for watchOS
# - libFFI          - build libFFI for all platforms (except macOS)
# - libFFI-iOS      - build libFFI for iOS
# - libFFI-tvOS     - build libFFI for tvOS
# - libFFI-watchOS  - build libFFI for watchOS
# - Python          - build Python for all platforms
# - Python-macOS    - build Python for macOS
# - Python-iOS      - build Python for iOS
# - Python-tvOS     - build Python for tvOS
# - Python-watchOS  - build Python for watchOS

# Current director
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=custom

# Version of packages that will be compiled by this meta-package
# PYTHON_VERSION is the full version number (e.g., 3.10.0b3)
# PYTHON_MICRO_VERSION is the full version number, without any alpha/beta/rc suffix. (e.g., 3.10.0)
# PYTHON_VER is the major/minor version (e.g., 3.10)
PYTHON_VERSION=3.10.13
PYTHON_MICRO_VERSION=$(shell echo $(PYTHON_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_VER=$(basename $(PYTHON_VERSION))

BZIP2_VERSION=1.0.8

XZ_VERSION=5.4.4

# Preference is to use OpenSSL 3; however, Cryptography 3.4.8 (and
# probably some other packages as well) only works with 1.1.1, so
# we need to preserve the ability to build the older OpenSSL (for now...)
OPENSSL_VERSION=3.1.2
# OPENSSL_VERSION_NUMBER=1.1.1
# OPENSSL_REVISION=v
# OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

LIBFFI_VERSION=3.4.4

# Supported OS and dependencies
DEPENDENCIES=BZip2 XZ OpenSSL libFFI
OS_LIST=macOS iOS tvOS watchOS

CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
VERSION_MIN-macOS=10.15
CFLAGS-macOS=-mmacosx-version-min=$(VERSION_MIN-macOS)

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64
VERSION_MIN-iOS=12.0
CFLAGS-iOS=-mios-version-min=$(VERSION_MIN-iOS)

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvsimulator.arm64 appletvos.arm64
VERSION_MIN-tvOS=9.0
CFLAGS-tvOS=-mtvos-version-min=$(VERSION_MIN-tvOS)
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.x86_64 watchsimulator.arm64 watchos.arm64_32
VERSION_MIN-watchOS=4.0
CFLAGS-watchOS=-mwatchos-version-min=$(VERSION_MIN-watchOS)
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

# The architecture of the machine doing the build
HOST_ARCH=$(shell uname -m)
HOST_PYTHON=install/macOS/macosx/python-$(PYTHON_VERSION)
HOST_PYTHON_EXE=$(HOST_PYTHON)/bin/python3
BDIST_WHEEL=$(HOST_PYTHON)/lib/python$(PYTHON_VER)/site-packages/wheel/bdist_wheel.py

# Force the path to be minimal. This ensures that anything in the user environment
# (in particular, homebrew and user-provided Python installs) aren't inadvertently
# linked into the support package.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

# Build for all operating systems
all: $(OS_LIST)

.PHONY: \
	all clean distclean update-patch vars wheels \
	$(foreach product,$(PRODUCTS),$(product) $(foreach os,$(OS_LIST),$(product)-$(os) clean-$(product) clean-$(product)-$(os))) \
	$(foreach product,$(PRODUCTS),$(product)-wheels $(foreach os,$(OS_LIST),$(product)-wheels-$(os) clean-$(product)-wheels-$(os))) \
	$(foreach os,$(OS_LIST),$(os) wheels-$(os) clean-$(os) clean-wheels-$(os) vars-$(os))

# Clean all builds
clean:
	rm -rf build install merge dist support wheels

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

downloads: \
		downloads/bzip2-$(BZIP2_VERSION).tar.gz \
		downloads/xz-$(XZ_VERSION).tar.gz \
		downloads/openssl-$(OPENSSL_VERSION).tar.gz \
		downloads/libffi-$(LIBFFI_VERSION).tar.gz \
		downloads/Python-$(PYTHON_VERSION).tar.gz

update-patch:
	# Generate a diff from the clone of the python/cpython Github repository,
	# comparing between the current state of the 3.X branch against the v3.X.Y
	# tag associated with the release being built. This allows you to
	# maintain a branch that contains custom patches against the default Python.
	# The patch archived in this respository is based on github.com/freakboy3742/cpython
	# Requires patchutils (installable via `brew install patchutils`); this
	# also means we need to re-introduce homebrew to the path for the filterdiff
	# call
	if [ -z "$(PYTHON_REPO_DIR)" ]; then echo "\n\nPYTHON_REPO_DIR must be set to the root of your Python github checkout\n\n"; fi
	cd $(PYTHON_REPO_DIR) && \
		git diff -D v$(PYTHON_VERSION) $(PYTHON_VER) \
			| PATH="/usr/local/bin:/opt/homebrew/bin:$(PATH)" filterdiff \
				-X $(PROJECT_DIR)/patch/Python/diff.exclude -p 1 --clean \
					> $(PROJECT_DIR)/patch/Python/Python.patch

###########################################################################
# Setup: BZip2
###########################################################################

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tar.gz:
	@echo ">>> Download BZip2 sources"
	curl $(CURL_FLAGS) -o $@ \
		https://sourceware.org/pub/bzip2/$(notdir $@)

###########################################################################
# Setup: XZ (LZMA)
###########################################################################

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tar.gz:
	@echo ">>> Download XZ sources"
	curl $(CURL_FLAGS) -o $@ \
		https://tukaani.org/xz/$(notdir $@)

###########################################################################
# Setup: OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tar.gz:
	@echo ">>> Download OpenSSL sources"
	curl $(CURL_FLAGS) -o $@ \
		https://openssl.org/source/$(notdir $@) \
		|| curl $(CURL_FLAGS) -o $@ \
			https://openssl.org/source/old/$(basename $(OPENSSL_VERSION))/$(notdir $@)

###########################################################################
# Setup: libFFI
###########################################################################

# Download original libFFI source code archive.
downloads/libffi-$(LIBFFI_VERSION).tar.gz:
	@echo ">>> Download libFFI sources"
	curl $(CURL_FLAGS) -o $@ \
		https://github.com/libffi/libffi/releases/download/v$(LIBFFI_VERSION)/$(notdir $@)

###########################################################################
# Setup: Python
###########################################################################

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tar.gz:
	@echo ">>> Download Python sources"
	curl $(CURL_FLAGS) -o $@ \
		https://www.python.org/ftp/python/$(PYTHON_MICRO_VERSION)/$(basename $(basename $(notdir $@))).tgz

###########################################################################
# Build for specified target (from $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 - target (e.g., iphonesimulator.x86_64, iphoneos.arm64)
# - $2 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build-target
target=$1
os=$2

OS_LOWER-$(target)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')
WHEEL_TAG-$(target)=py3-none-$$(OS_LOWER-$(target))_$$(shell echo $$(VERSION_MIN-$(os))_$(target) | sed "s/\./_/g")

# $(target) can be broken up into is composed of $(SDK).$(ARCH)
SDK-$(target)=$$(basename $(target))
ARCH-$(target)=$$(subst .,,$$(suffix $(target)))

ifeq ($(os),macOS)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-darwin
else
	ifeq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))
	else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))-simulator
	endif
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
CPP-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target)) -E
CXX-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
AR-$(target)=xcrun --sdk $$(SDK-$(target)) ar
CFLAGS-$(target)=\
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))
LDFLAGS-$(target)=\
	-isysroot $$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))

###########################################################################
# Target: BZip2
###########################################################################

BZIP2_SRCDIR-$(target)=build/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(target)=$$(BZIP2_INSTALL-$(target))/lib/libbz2.a
BZIP2_WHEEL-$(target)=wheels/dist/bzip2/bzip2-$(BZIP2_VERSION)-1-$$(WHEEL_TAG-$(target)).whl
BZIP2_WHEEL_DISTINFO-$(target)=$$(BZIP2_INSTALL-$(target))/wheel/bzip2-$(BZIP2_VERSION).dist-info

$$(BZIP2_SRCDIR-$(target))/Makefile: downloads/bzip2-$(BZIP2_VERSION).tar.gz
	@echo ">>> Unpack BZip2 sources for $(target)"
	mkdir -p $$(BZIP2_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(BZIP2_SRCDIR-$(target))
	# Touch the makefile to ensure that Make identifies it as up to date.
	touch $$(BZIP2_SRCDIR-$(target))/Makefile

$$(BZIP2_LIB-$(target)): $$(BZIP2_SRCDIR-$(target))/Makefile
	@echo ">>> Build BZip2 for $(target)"
	cd $$(BZIP2_SRCDIR-$(target)) && \
		make install \
			PREFIX="$$(BZIP2_INSTALL-$(target))" \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			2>&1 | tee -a ../bzip2-$(BZIP2_VERSION).build.log

$$(BZIP2_WHEEL-$(target)): $$(BZIP2_LIB-$(target)) $$(BDIST_WHEEL)
	@echo ">>> Build BZip2 wheel for $(target)"
	mkdir -p $$(BZIP2_WHEEL_DISTINFO-$(target))
	mkdir -p $$(BZIP2_INSTALL-$(target))/wheel/opt

	# Copy distributable content
	cp -r $$(BZIP2_INSTALL-$(target))/include $$(BZIP2_INSTALL-$(target))/wheel/opt/include
	cp -r $$(BZIP2_INSTALL-$(target))/lib $$(BZIP2_INSTALL-$(target))/wheel/opt/lib

	# Copy LICENSE file
	cp $$(BZIP2_SRCDIR-$(target))/LICENSE $$(BZIP2_WHEEL_DISTINFO-$(target))

	# Write package metadata
	echo "Metadata-Version: 1.2" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/METADATA
	echo "Name: bzip2" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/METADATA
	echo "Version: $(BZIP2_VERSION)" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/METADATA
	echo "Summary: " >> $$(BZIP2_WHEEL_DISTINFO-$(target))/METADATA
	echo "Download-URL: " >> $$(BZIP2_WHEEL_DISTINFO-$(target))/METADATA

	# Write wheel metadata
	echo "Wheel-Version: 1.0" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Root-Is-Purelib: false" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Generator: Python-Apple-support.BeeWare" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Build: 1" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Tag: $$(WHEEL_TAG-$(target))" >> $$(BZIP2_WHEEL_DISTINFO-$(target))/WHEEL

	# Pack the wheel
	mkdir -p wheels/dist/bzip2
	$(HOST_PYTHON_EXE) -m wheel pack $$(BZIP2_INSTALL-$(target))/wheel --dest-dir wheels/dist/bzip2 --build-number 1

###########################################################################
# Target: XZ (LZMA)
###########################################################################

XZ_SRCDIR-$(target)=build/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_LIB-$(target)=$$(XZ_INSTALL-$(target))/lib/liblzma.a
XZ_WHEEL-$(target)=wheels/dist/xz/xz-$(XZ_VERSION)-1-$$(WHEEL_TAG-$(target)).whl
XZ_WHEEL_DISTINFO-$(target)=$$(XZ_INSTALL-$(target))/wheel/xz-$(XZ_VERSION).dist-info

$$(XZ_SRCDIR-$(target))/Makefile: downloads/xz-$(XZ_VERSION).tar.gz
	@echo ">>> Unpack XZ sources for $(target)"
	mkdir -p $$(XZ_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(XZ_SRCDIR-$(target))
	# Patch the source to add support for new platforms
	cd $$(XZ_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/xz-$(XZ_VERSION).patch
	# Configure the build
	cd $$(XZ_SRCDIR-$(target)) && \
		./configure \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared \
			--enable-static \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(XZ_INSTALL-$(target))" \
			2>&1 | tee -a ../xz-$(XZ_VERSION).config.log

$$(XZ_LIB-$(target)): $$(XZ_SRCDIR-$(target))/Makefile
	@echo ">>> Build and install XZ for $(target)"
	cd $$(XZ_SRCDIR-$(target)) && \
		make install \
			2>&1 | tee -a ../xz-$(XZ_VERSION).build.log

$$(XZ_WHEEL-$(target)): $$(XZ_LIB-$(target)) $$(BDIST_WHEEL)
	@echo ">>> Build XZ wheel for $(target)"
	mkdir -p $$(XZ_WHEEL_DISTINFO-$(target))
	mkdir -p $$(XZ_INSTALL-$(target))/wheel/opt

	# Copy distributable content
	cp -r $$(XZ_INSTALL-$(target))/include $$(XZ_INSTALL-$(target))/wheel/opt/include
	cp -r $$(XZ_INSTALL-$(target))/lib $$(XZ_INSTALL-$(target))/wheel/opt/lib

	# Copy license files
	cp $$(XZ_SRCDIR-$(target))/COPYING $$(XZ_WHEEL_DISTINFO-$(target))/LICENSE
	cp $$(XZ_SRCDIR-$(target))/COPYING.* $$(XZ_WHEEL_DISTINFO-$(target))

	# Write package metadata
	echo "Metadata-Version: 1.2" >> $$(XZ_WHEEL_DISTINFO-$(target))/METADATA
	echo "Name: xz" >> $$(XZ_WHEEL_DISTINFO-$(target))/METADATA
	echo "Version: $(XZ_VERSION)" >> $$(XZ_WHEEL_DISTINFO-$(target))/METADATA
	echo "Summary: " >> $$(XZ_WHEEL_DISTINFO-$(target))/METADATA
	echo "Download-URL: " >> $$(XZ_WHEEL_DISTINFO-$(target))/METADATA

	# Write wheel metadata
	echo "Wheel-Version: 1.0" >> $$(XZ_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Root-Is-Purelib: false" >> $$(XZ_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Generator: Python-Apple-support.BeeWare" >> $$(XZ_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Build: 1" >> $$(XZ_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Tag: $$(WHEEL_TAG-$(target))" >> $$(XZ_WHEEL_DISTINFO-$(target))/WHEEL

	# Pack the wheel
	mkdir -p wheels/dist/xz
	$(HOST_PYTHON_EXE) -m wheel pack $$(XZ_INSTALL-$(target))/wheel --dest-dir wheels/dist/xz --build-number 1

###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_SRCDIR-$(target)=build/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libssl.a
OPENSSL_CRYPTO_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libcrypto.a
OPENSSL_WHEEL-$(target)=wheels/dist/openssl/openssl-$(OPENSSL_VERSION)-1-$$(WHEEL_TAG-$(target)).whl
OPENSSL_WHEEL_DISTINFO-$(target)=$$(OPENSSL_INSTALL-$(target))/wheel/openssl-$(OPENSSL_VERSION).dist-info

$$(OPENSSL_SRCDIR-$(target))/is_configured: downloads/openssl-$(OPENSSL_VERSION).tar.gz
	@echo ">>> Unpack and configure OpenSSL sources for $(target)"
	mkdir -p $$(OPENSSL_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(OPENSSL_SRCDIR-$(target))

ifneq ($(os),macOS)
	# Patch code to disable the use of fork as it's not available on $(os)
ifeq ($(OPENSSL_VERSION_NUMBER),1.1.1)
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/speed.c
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/ocsp.c
else
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/include/http_server.h
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_SRCDIR-$(target))/apps/speed.c
endif
endif

	# Configure the OpenSSL build
ifeq ($(os),macOS)
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		./Configure darwin64-$$(ARCH-$(target))-cc no-tests \
			--prefix="$$(OPENSSL_INSTALL-$(target))" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).config.log
else
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		./Configure iphoneos-cross no-asm no-tests \
			--prefix="$$(OPENSSL_INSTALL-$(target))" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).config.log
endif
	# The OpenSSL Makefile is... interesting. Invoking `make all` or `make
	# install` *modifies the Makefile*. Therefore, we can't use the Makefile as
	# a build dependency, because building/installing dirties the target that
	# was used as a dependency. To compensate, create a dummy file as a marker
	# for whether OpenSSL has been configured, and use *that* as a reference.
	date > $$(OPENSSL_SRCDIR-$(target))/is_configured

$$(OPENSSL_SRCDIR-$(target))/libssl.a: $$(OPENSSL_SRCDIR-$(target))/is_configured
	@echo ">>> Build OpenSSL for $(target)"
	# OpenSSL's `all` target modifies the Makefile;
	# use the raw targets that make up all and it's dependencies
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make build_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).build.log

$$(OPENSSL_SSL_LIB-$(target)): $$(OPENSSL_SRCDIR-$(target))/libssl.a
	@echo ">>> Install OpenSSL for $(target)"
	# Install just the software (not the docs)
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make install_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).install.log

$$(OPENSSL_WHEEL-$(target)): $$(OPENSSL_LIB-$(target)) $$(BDIST_WHEEL)
	@echo ">>> Build OpenSSL wheel for $(target)"
	mkdir -p $$(OPENSSL_WHEEL_DISTINFO-$(target))
	mkdir -p $$(OPENSSL_INSTALL-$(target))/wheel/opt

	# Copy distributable content
	cp -r $$(OPENSSL_INSTALL-$(target))/include $$(OPENSSL_INSTALL-$(target))/wheel/opt/include
	cp -r $$(OPENSSL_INSTALL-$(target))/lib $$(OPENSSL_INSTALL-$(target))/wheel/opt/lib

	# Remove dynamic library content
	rm -f $$(OPENSSL_INSTALL-$(target))/wheel/opt/lib/*.dylib

	# Copy LICENSE file
	# OpenSSL 1.1.1 uses LICENSE; OpenSSL 3 uses LICENSE.txt
	if [ -f "$$(OPENSSL_SRCDIR-$(target))/LICENSE.txt" ]; then \
		cp $$(OPENSSL_SRCDIR-$(target))/LICENSE.txt $$(OPENSSL_WHEEL_DISTINFO-$(target))/LICENSE; \
	else \
		cp $$(OPENSSL_SRCDIR-$(target))/LICENSE $$(OPENSSL_WHEEL_DISTINFO-$(target))/LICENSE; \
	fi

	# Write package metadata
	echo "Metadata-Version: 1.2" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/METADATA
	echo "Name: openssl" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/METADATA
	echo "Version: $(OPENSSL_VERSION)" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/METADATA
	echo "Summary: " >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/METADATA
	echo "Download-URL: " >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/METADATA

	# Write wheel metadata
	echo "Wheel-Version: 1.0" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Root-Is-Purelib: false" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Generator: Python-Apple-support.BeeWare" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Build: 1" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Tag: $$(WHEEL_TAG-$(target))" >> $$(OPENSSL_WHEEL_DISTINFO-$(target))/WHEEL

	# Pack the wheel
	mkdir -p wheels/dist/openssl
	$(HOST_PYTHON_EXE) -m wheel pack $$(OPENSSL_INSTALL-$(target))/wheel --dest-dir wheels/dist/openssl --build-number 1

###########################################################################
# Target: libFFI
###########################################################################

# macOS builds use the system libFFI, so there's no need to do
# a per-target build on macOS.
# The configure step is performed as part of the OS-level build.
ifneq ($(os),macOS)

LIBFFI_SRCDIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)
LIBFFI_SRCDIR-$(target)=$$(LIBFFI_SRCDIR-$(os))/build_$$(SDK-$(target))-$$(ARCH-$(target))
LIBFFI_LIB-$(target)=$$(LIBFFI_SRCDIR-$(target))/.libs/libffi.a
LIBFFI_WHEEL-$(target)=wheels/dist/libffi/libffi-$(LIBFFI_VERSION)-1-$$(WHEEL_TAG-$(target)).whl
LIBFFI_WHEEL_DISTINFO-$(target)=$$(LIBFFI_SRCDIR-$(target))/wheel/libffi-$(LIBFFI_VERSION).dist-info

$$(LIBFFI_LIB-$(target)): $$(LIBFFI_SRCDIR-$(os))/darwin_common/include/ffi.h
	@echo ">>> Build libFFI for $(target)"
	cd $$(LIBFFI_SRCDIR-$(target)) && \
		make \
			2>&1 | tee -a ../../libffi-$(LIBFFI_VERSION).build.log

$$(LIBFFI_WHEEL-$(target)): $$(LIBFFI_LIB-$(target)) $$(BDIST_WHEEL)
	@echo ">>> Build libFFI wheel for $(target)"
	mkdir -p $$(LIBFFI_WHEEL_DISTINFO-$(target))
	mkdir -p $$(LIBFFI_SRCDIR-$(target))/wheel/opt

	# Copy distributable content
	cp -r $$(LIBFFI_SRCDIR-$(target))/include $$(LIBFFI_SRCDIR-$(target))/wheel/opt/include
	cp -r $$(LIBFFI_SRCDIR-$(target))/.libs $$(LIBFFI_SRCDIR-$(target))/wheel/opt/lib

	# Remove dynamic library content
	rm -f $$(LIBFFI_SRCDIR-$(target))/wheel/opt/lib/*.dylib

	# Copy LICENSE file
	cp $$(LIBFFI_SRCDIR-$(os))/LICENSE $$(LIBFFI_WHEEL_DISTINFO-$(target))

	# Write package metadata
	echo "Metadata-Version: 1.2" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/METADATA
	echo "Name: libffi" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/METADATA
	echo "Version: $(LIBFFI_VERSION)" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/METADATA
	echo "Summary: " >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/METADATA
	echo "Download-URL: " >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/METADATA

	# Write wheel metadata
	echo "Wheel-Version: 1.0" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Root-Is-Purelib: false" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Generator: Python-Apple-support.BeeWare" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Build: 1" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/WHEEL
	echo "Tag: $$(WHEEL_TAG-$(target))" >> $$(LIBFFI_WHEEL_DISTINFO-$(target))/WHEEL

	# Pack the wheel
	mkdir -p wheels/dist/libffi
	$(HOST_PYTHON_EXE) -m wheel pack $$(LIBFFI_SRCDIR-$(target))/wheel --dest-dir wheels/dist/libffi --build-number 1

endif

###########################################################################
# Target: Python
###########################################################################

# macOS builds are compiled as a single universal2 build.
# The macOS Python build is configured in the `build-sdk` macro, rather than the
# `build-target` macro.
ifneq ($(os),macOS)

PYTHON_SRCDIR-$(target)=build/$(os)/$(target)/python-$(PYTHON_VERSION)
PYTHON_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/python-$(PYTHON_VERSION)
PYTHON_LIB-$(target)=$$(PYTHON_INSTALL-$(target))/lib/libpython$(PYTHON_VER).a

$$(PYTHON_SRCDIR-$(target))/Makefile: \
		downloads/Python-$(PYTHON_VERSION).tar.gz \
		$$(BZIP2_FATLIB-$$(SDK-$(target))) \
		$$(XZ_FATLIB-$$(SDK-$(target))) \
		$$(OPENSSL_FATINCLUDE-$$(SDK-$(target))) $$(OPENSSL_SSL_FATLIB-$$(SDK-$(target))) $$(OPENSSL_CRYPTO_FATLIB-$$(SDK-$(target))) \
		$$(LIBFFI_FATLIB-$$(SDK-$(target))) \
		$$(PYTHON_XCFRAMEWORK-macOS)
	@echo ">>> Unpack and configure Python for $(target)"
	mkdir -p $$(PYTHON_SRCDIR-$(target))
	tar zxf downloads/Python-$(PYTHON_VERSION).tar.gz --strip-components 1 -C $$(PYTHON_SRCDIR-$(target))
	# Apply target Python patches
	cd $$(PYTHON_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Configure target Python
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PATH)" \
		./configure \
			AR="$$(AR-$(target))" \
			CC="$$(CC-$(target))" \
			CPP="$$(CPP-$(target))" \
			CXX="$$(CXX-$(target))" \
			CFLAGS="$$(CFLAGS-$(target)) -I$$(BZIP2_MERGE-$$(SDK-$(target)))/include -I$$(XZ_MERGE-$$(SDK-$(target)))/include" \
			LDFLAGS="$$(LDFLAGS-$(target)) -L$$(BZIP2_MERGE-$$(SDK-$(target)))/lib -L$$(XZ_MERGE-$$(SDK-$(target)))/lib" \
			LIBFFI_INCLUDEDIR="$$(LIBFFI_MERGE-$$(SDK-$(target)))/include" \
			LIBFFI_LIBDIR="$$(LIBFFI_MERGE-$$(SDK-$(target)))/lib" \
			LIBFFI_LIB="ffi" \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(PYTHON_INSTALL-$(target))" \
			--enable-ipv6 \
			--with-openssl="$$(OPENSSL_MERGE-$$(SDK-$(target)))" \
			--without-ensurepip \
			ac_cv_file__dev_ptmx=no \
			ac_cv_file__dev_ptc=no \
			$$(PYTHON_CONFIGURE-$(os)) \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).config.log

$$(PYTHON_SRCDIR-$(target))/python.exe: $$(PYTHON_SRCDIR-$(target))/Makefile
	@echo ">>> Build Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PATH)" \
			make all \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).build.log

$$(PYTHON_LIB-$(target)): $$(PYTHON_SRCDIR-$(target))/python.exe
	@echo ">>> Install Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PATH)" \
			make install \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).install.log

endif

###########################################################################
# Target: Debug
###########################################################################

vars-$(target):
	@echo ">>> Environment variables for $(target)"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "TARGET_TRIPLE-$(target): $$(TARGET_TRIPLE-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CC-$(target): $$(CC-$(target))"
	@echo "CPP-$(target): $$(CPP-$(target))"
	@echo "CFLAGS-$(target): $$(CFLAGS-$(target))"
	@echo "LDFLAGS-$(target): $$(LDFLAGS-$(target))"
	@echo "BZIP2_SRCDIR-$(target): $$(BZIP2_SRCDIR-$(target))"
	@echo "BZIP2_INSTALL-$(target): $$(BZIP2_INSTALL-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "BZIP2_WHEEL-$(target): $$(BZIP2_WHEEL-$(target))"
	@echo "BZIP2_WHEEL_DISTINFO-$(target): $$(BZIP2_WHEEL_DISTINFO-$(target))"
	@echo "XZ_SRCDIR-$(target): $$(XZ_SRCDIR-$(target))"
	@echo "XZ_INSTALL-$(target): $$(XZ_INSTALL-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "XZ_WHEEL-$(target): $$(XZ_WHEEL-$(target))"
	@echo "XZ_WHEEL_DISTINFO-$(target): $$(XZ_WHEEL_DISTINFO-$(target))"
	@echo "OPENSSL_SRCDIR-$(target): $$(OPENSSL_SRCDIR-$(target))"
	@echo "OPENSSL_INSTALL-$(target): $$(OPENSSL_INSTALL-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "OPENSSL_CRYPTO_LIB-$(target): $$(OPENSSL_CRYPTO_LIB-$(target))"
	@echo "OPENSSL_WHEEL-$(target): $$(OPENSSL_WHEEL-$(target))"
	@echo "OPENSSL_WHEEL_DISTINFO-$(target): $$(OPENSSL_WHEEL_DISTINFO-$(target))"
	@echo "LIBFFI_SRCDIR-$(target): $$(LIBFFI_SRCDIR-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
	@echo "LIBFFI_WHEEL-$(target): $$(LIBFFI_WHEEL-$(target))"
	@echo "LIBFFI_WHEEL_DISTINFO-$(target): $$(LIBFFI_WHEEL_DISTINFO-$(target))"
	@echo "PYTHON_SRCDIR-$(target): $$(PYTHON_SRCDIR-$(target))"
	@echo "PYTHON_INSTALL-$(target): $$(PYTHON_INSTALL-$(target))"
	@echo "PYTHON_LIB-$(target): $$(PYTHON_LIB-$(target))"
	@echo

endef # build-target

###########################################################################
# Build for specified sdk (extracted from the base names in $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 sdk (e.g., iphoneos, iphonesimulator)
# - $2 OS (e.g., iOS, tvOS)
#
###########################################################################
define build-sdk
sdk=$1
os=$2

OS_LOWER-$(sdk)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

SDK_TARGETS-$(sdk)=$$(filter $(sdk).%,$$(TARGETS-$(os)))
SDK_ARCHES-$(sdk)=$$(sort $$(subst .,,$$(suffix $$(SDK_TARGETS-$(sdk)))))

ifeq ($$(findstring simulator,$(sdk)),)
SDK_SLICE-$(sdk)=$$(OS_LOWER-$(sdk))-$$(shell echo $$(SDK_ARCHES-$(sdk)) | sed "s/ /_/g")
else
SDK_SLICE-$(sdk)=$$(OS_LOWER-$(sdk))-$$(shell echo $$(SDK_ARCHES-$(sdk)) | sed "s/ /_/g")-simulator
endif

CC-$(sdk)=xcrun --sdk $(sdk) clang
CPP-$(sdk)=xcrun --sdk $(sdk) clang -E
CFLAGS-$(sdk)=$$(CFLAGS-$(os))
LDFLAGS-$(sdk)=$$(CFLAGS-$(os))

# Predeclare SDK constants that are used by the build-target macro

BZIP2_MERGE-$(sdk)=$(PROJECT_DIR)/merge/$(os)/$(sdk)/bzip2-$(BZIP2_VERSION)
BZIP2_FATLIB-$(sdk)=$$(BZIP2_MERGE-$(sdk))/lib/libbz2.a

XZ_MERGE-$(sdk)=$(PROJECT_DIR)/merge/$(os)/$(sdk)/xz-$(XZ_VERSION)
XZ_FATLIB-$(sdk)=$$(XZ_MERGE-$(sdk))/lib/liblzma.a

OPENSSL_MERGE-$(sdk)=$(PROJECT_DIR)/merge/$(os)/$(sdk)/openssl-$(OPENSSL_VERSION)
OPENSSL_FATINCLUDE-$(sdk)=$$(OPENSSL_MERGE-$(sdk))/include
OPENSSL_SSL_FATLIB-$(sdk)=$$(OPENSSL_MERGE-$(sdk))/lib/libssl.a
OPENSSL_CRYPTO_FATLIB-$(sdk)=$$(OPENSSL_MERGE-$(sdk))/lib/libcrypto.a

LIBFFI_MERGE-$(sdk)=$(PROJECT_DIR)/merge/$(os)/$(sdk)/libffi-$(LIBFFI_VERSION)
LIBFFI_FATLIB-$(sdk)=$$(LIBFFI_MERGE-$(sdk))/lib/libffi.a

PYTHON_MERGE-$(sdk)=$(PROJECT_DIR)/merge/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_FATLIB-$(sdk)=$$(PYTHON_MERGE-$(sdk))/libPython$(PYTHON_VER).a
PYTHON_FATINCLUDE-$(sdk)=$$(PYTHON_MERGE-$(sdk))/Headers
PYTHON_FATSTDLIB-$(sdk)=$$(PYTHON_MERGE-$(sdk))/python-stdlib

# Expand the build-target macro for target on this OS
$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(eval $$(call build-target,$$(target),$(os))))

###########################################################################
# SDK: BZip2
###########################################################################

$$(BZIP2_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(BZIP2_LIB-$$(target)))
	@echo ">>> Build BZip2 fat library for $(sdk)"
	mkdir -p $$(BZIP2_MERGE-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a merge/$(os)/$(sdk)/bzip2-$(BZIP2_VERSION).lipo.log
	# Copy headers from the first target associated with the $(sdk) SDK
	cp -r $$(BZIP2_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(BZIP2_MERGE-$(sdk))

###########################################################################
# SDK: XZ (LZMA)
###########################################################################

$$(XZ_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(XZ_LIB-$$(target)))
	@echo ">>> Build XZ fat library for $(sdk)"
	mkdir -p $$(XZ_MERGE-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a merge/$(os)/$(sdk)/xz-$(XZ_VERSION).lipo.log
	# Copy headers from the first target associated with the $(sdk) SDK
	cp -r $$(XZ_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(XZ_MERGE-$(sdk))

###########################################################################
# SDK: OpenSSL
###########################################################################

$$(OPENSSL_FATINCLUDE-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)))
	@echo ">>> Copy OpenSSL headers from the first target associated with the SDK"
	mkdir -p $$(OPENSSL_MERGE-$(sdk))
	cp -r $$(OPENSSL_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(OPENSSL_MERGE-$(sdk))

$$(OPENSSL_SSL_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)))
	@echo ">>> Build OpenSSL ssl fat library for $(sdk)"
	mkdir -p $$(OPENSSL_MERGE-$(sdk))/lib
	lipo -create -output $$@ \
		$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target))) \
		2>&1 | tee -a merge/$(os)/$(sdk)/openssl-$(OPENSSL_VERSION).ssl.lipo.log

$$(OPENSSL_CRYPTO_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_CRYPTO_LIB-$$(target)))
	@echo ">>> Build OpenSSL crypto fat library for $(sdk)"
	mkdir -p $$(OPENSSL_MERGE-$(sdk))/lib
	lipo -create -output $$@ \
		$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_CRYPTO_LIB-$$(target))) \
		2>&1 | tee -a merge/$(os)/$(sdk)/openssl-$(OPENSSL_VERSION).crypto.lipo.log

###########################################################################
# SDK: libFFI
###########################################################################

$$(LIBFFI_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(LIBFFI_LIB-$$(target)))
	@echo ">>> Build libFFI fat library for $(sdk)"
	mkdir -p $$(LIBFFI_MERGE-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a merge/$(os)/$(sdk)/libffi-$(LIBFFI_VERSION).lipo.log
	# Copy headers from the first target associated with the $(sdk) SDK
	cp -f -r $$(LIBFFI_SRCDIR-$(os))/darwin_common/include \
		$$(LIBFFI_MERGE-$(sdk))
	cp -f -r $$(LIBFFI_SRCDIR-$(os))/darwin_$$(OS_LOWER-$(sdk))/include/* \
		$$(LIBFFI_MERGE-$(sdk))/include

###########################################################################
# SDK: Python
###########################################################################

# macOS builds are compiled as a single universal2 build. The fat library is a
# direct copy of OS build, and the headers and standard library are unmodified
# from the versions produced by the OS build.
ifeq ($(os),macOS)

PYTHON_SRCDIR-$(sdk)=build/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_LIB-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/lib/libpython$(PYTHON_VER).a

$$(PYTHON_SRCDIR-$(sdk))/Makefile: \
		$$(BZIP2_FATLIB-$$(sdk)) \
		$$(XZ_FATLIB-$$(sdk)) \
		$$(OPENSSL_FATINCLUDE-$$(sdk)) $$(OPENSSL_SSL_FATLIB-$$(sdk)) $$(OPENSSL_CRYPTO_FATLIB-$$(sdk)) \
		downloads/Python-$(PYTHON_VERSION).tar.gz
	@echo ">>> Unpack and configure Python for $(sdk)"
	mkdir -p $$(PYTHON_SRCDIR-$(sdk))
	tar zxf downloads/Python-$(PYTHON_VERSION).tar.gz --strip-components 1 -C $$(PYTHON_SRCDIR-$(sdk))
	# Apply target Python patches
	cd $$(PYTHON_SRCDIR-$(sdk)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Configure target Python
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		./configure \
			CC="$$(CC-$(sdk))" \
			CPP="$$(CPP-$(sdk))" \
			CFLAGS="$$(CFLAGS-$(sdk)) -I$$(BZIP2_MERGE-$(sdk))/include -I$$(XZ_MERGE-$(sdk))/include" \
			LDFLAGS="$$(LDFLAGS-$(sdk)) -L$$(XZ_MERGE-$(sdk))/lib -L$$(BZIP2_MERGE-$(sdk))/lib" \
			--prefix="$$(PYTHON_INSTALL-$(sdk))" \
			--enable-ipv6 \
			--enable-universalsdk \
			--with-openssl="$$(OPENSSL_MERGE-$(sdk))" \
			--with-universal-archs=universal2 \
			--without-ensurepip \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).config.log

$$(PYTHON_SRCDIR-$(sdk))/python.exe: \
		$$(PYTHON_SRCDIR-$(sdk))/Makefile
	@echo ">>> Build Python for $(sdk)"
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		make all \
		2>&1 | tee -a ../python-$(PYTHON_VERSION).build.log

$(HOST_PYTHON_EXE) $$(PYTHON_LIB-$(sdk)): $$(PYTHON_SRCDIR-$(sdk))/python.exe
	@echo ">>> Install Python for $(sdk)"
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		make install \
		2>&1 | tee -a ../python-$(PYTHON_VERSION).install.log

$$(PYTHON_FATLIB-$(sdk)): $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python fat library for $(sdk)"
	mkdir -p $$(dir $$(PYTHON_FATLIB-$(sdk)))
	# The macosx static library is already fat; copy it as-is
	cp $$(PYTHON_LIB-$(sdk)) $$(PYTHON_FATLIB-$(sdk))

$$(PYTHON_FATINCLUDE-$(sdk)): $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python fat library for $(sdk)"
	# The macosx headers are already fat; copy as-is
	cp -r $$(PYTHON_INSTALL-$(sdk))/include/python$(PYTHON_VER) $$(PYTHON_FATINCLUDE-$(sdk))

$$(PYTHON_FATSTDLIB-$(sdk)): $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python stdlib library for $(sdk)"
	# The macosx stdlib is already fat; copy it as-is
	cp -r $$(PYTHON_INSTALL-$(sdk))/lib/python$(PYTHON_VER) $$(PYTHON_FATSTDLIB-$(sdk))

else

# Non-macOS builds need to be merged on a per-SDK basis. The merge covers:
# * Merging a fat libPython.a
# * Installing an architecture-sensitive pyconfig.h
# * Merging fat versions of the standard library lib-dynload folder

$$(PYTHON_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_LIB-$$(target)))
	@echo ">>> Build Python fat library for the $(sdk) SDK"
	mkdir -p $$(dir $$(PYTHON_FATLIB-$(sdk)))
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a merge/$(os)/$(sdk)/python-$(PYTHON_VERSION).lipo.log

$$(PYTHON_FATINCLUDE-$(sdk)): $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python fat headers for the $(sdk) SDK"
	# Copy headers as-is from the first target in the $(sdk) SDK
	cp -r $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include/python$(PYTHON_VER) $$(PYTHON_FATINCLUDE-$(sdk))
	# Copy the cross-target header from the patch folder
	cp $(PROJECT_DIR)/patch/Python/pyconfig-$(os).h $$(PYTHON_FATINCLUDE-$(sdk))/pyconfig.h
	# Add the individual headers from each target in an arch-specific name
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_INSTALL-$$(target))/include/python$(PYTHON_VER)/pyconfig.h $$(PYTHON_FATINCLUDE-$(sdk))/pyconfig-$$(ARCH-$$(target)).h; )

$$(PYTHON_FATSTDLIB-$(sdk)): $$(PYTHON_FATLIB-$(sdk))
	@echo ">>> Build Python stdlib for the $(sdk) SDK"
	mkdir -p $$(PYTHON_FATSTDLIB-$(sdk))
	# Copy stdlib from the first target associated with the $(sdk) SDK
	cp -r $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/lib/python$(PYTHON_VER)/ $$(PYTHON_FATSTDLIB-$(sdk))

	# Delete the single-SDK parts of the standard library
	rm -rf \
		$$(PYTHON_FATSTDLIB-$(sdk))/_sysconfigdata__*.py \
		$$(PYTHON_FATSTDLIB-$(sdk))/config-* \
		$$(PYTHON_FATSTDLIB-$(sdk))/lib-dynload/*

	# Copy the cross-target _sysconfigdata module from the patch folder
	cp $(PROJECT_DIR)/patch/Python/_sysconfigdata__$$(OS_LOWER-$(sdk))_$(sdk).py $$(PYTHON_FATSTDLIB-$(sdk))

	# Copy the individual _sysconfigdata modules into names that include the architecture
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/_sysconfigdata__$$(OS_LOWER-$(sdk))_$(sdk).py $$(PYTHON_FATSTDLIB-$(sdk))/_sysconfigdata__$$(OS_LOWER-$(sdk))_$(sdk)_$$(ARCH-$$(target)).py; )

	# Copy the individual config modules directories into names that include the architecture
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp -r $$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/config-$(PYTHON_VER)-$(sdk) $$(PYTHON_FATSTDLIB-$(sdk))/config-$(PYTHON_VER)-$$(target); )

	# Merge the binary modules from each target in the $(sdk) SDK into a single binary
	$$(foreach module,$$(wildcard $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/lib/python$(PYTHON_VER)/lib-dynload/*),lipo -create -output $$(PYTHON_FATSTDLIB-$(sdk))/lib-dynload/$$(notdir $$(module)) $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/lib-dynload/$$(notdir $$(module))); )

endif


###########################################################################
# SDK: Debug
###########################################################################

vars-$(sdk):
	@echo ">>> Environment variables for $(sdk)"
	@echo "SDK_TARGETS-$(sdk): $$(SDK_TARGETS-$(sdk))"
	@echo "SDK_ARCHES-$(sdk): $$(SDK_ARCHES-$(sdk))"
	@echo "SDK_SLICE-$(sdk): $$(SDK_SLICE-$(sdk))"
	@echo "CC-$(sdk): $$(CC-$(sdk))"
	@echo "CPP-$(sdk): $$(CPP-$(sdk))"
	@echo "CFLAGS-$(sdk): $$(CFLAGS-$(sdk))"
	@echo "LDFLAGS-$(sdk): $$(LDFLAGS-$(sdk))"
	@echo "BZIP2_MERGE-$(sdk): $$(BZIP2_MERGE-$(sdk))"
	@echo "BZIP2_FATLIB-$(sdk): $$(BZIP2_FATLIB-$(sdk))"
	@echo "XZ_MERGE-$(sdk): $$(XZ_MERGE-$(sdk))"
	@echo "XZ_FATLIB-$(sdk): $$(XZ_FATLIB-$(sdk))"
	@echo "OPENSSL_MERGE-$(sdk): $$(OPENSSL_MERGE-$(sdk))"
	@echo "OPENSSL_FATINCLUDE-$(sdk): $$(OPENSSL_FATINCLUDE-$(sdk))"
	@echo "OPENSSL_SSL_FATLIB-$(sdk): $$(OPENSSL_SSL_FATLIB-$(sdk))"
	@echo "OPENSSL_CRYPTO_FATLIB-$(sdk): $$(OPENSSL_CRYPTO_FATLIB-$(sdk))"
	@echo "LIBFFI_MERGE-$(sdk): $$(LIBFFI_MERGE-$(sdk))"
	@echo "LIBFFI_FATLIB-$(sdk): $$(LIBFFI_FATLIB-$(sdk))"
	@echo "PYTHON_MERGE-$(sdk): $$(PYTHON_MERGE-$(sdk))"
	@echo "PYTHON_FATLIB-$(sdk): $$(PYTHON_FATLIB-$(sdk))"
	@echo "PYTHON_FATINCLUDE-$(sdk): $$(PYTHON_FATINCLUDE-$(sdk))"
	@echo "PYTHON_FATSTDLIB-$(sdk): $$(PYTHON_FATSTDLIB-$(sdk))"
	@echo "PYTHON_SRCDIR-$(sdk): $$(PYTHON_SRCDIR-$(sdk))"
	@echo "PYTHON_INSTALL-$(sdk): $$(PYTHON_INSTALL-$(sdk))"
	@echo "PYTHON_LIB-$(sdk): $$(PYTHON_LIB-$(sdk))"
	@echo

endef # build-sdk

###########################################################################
# Build for specified OS (from $(OS_LIST))
###########################################################################
#
# Parameters:
# - $1 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build
os=$1

###########################################################################
# Build: Macro Expansions
###########################################################################

SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))

# Predeclare the Python XCFramework files so they can be referenced in SDK targets
PYTHON_XCFRAMEWORK-$(os)=support/$(PYTHON_VER)/$(os)/Python.xcframework
PYTHON_STDLIB-$(os)=support/$(PYTHON_VER)/$(os)/python-stdlib

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: BZip2
###########################################################################

BZip2-$(os): $$(foreach sdk,$$(SDKS-$(os)),$$(BZIP2_FATLIB-$$(sdk)))
BZip2-wheels-$(os): $$(foreach target,$$(TARGETS-$(os)),$$(BZIP2_WHEEL-$$(target)))

clean-BZip2-$(os):
	@echo ">>> Clean BZip2 build products on $(os)"
	rm -rf \
		build/$(os)/*/bzip2-$(BZIP2_VERSION) \
		build/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		install/$(os)/*/bzip2-$(BZIP2_VERSION) \
		install/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		merge/$(os)/*/bzip2-$(BZIP2_VERSION) \
		merge/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		wheels/dist/bzip2

clean-BZip2-wheels-$(os):
	rm -rf \
		install/$(os)/*/bzip2-$(BZIP2_VERSION)/wheel \
		wheels/dist/bzip2

###########################################################################
# Build: XZ (LZMA)
###########################################################################

XZ-$(os): $$(foreach sdk,$$(SDKS-$(os)),$$(XZ_FATLIB-$$(sdk)))
XZ-wheels-$(os): $$(foreach target,$$(TARGETS-$(os)),$$(XZ_WHEEL-$$(target)))

clean-XZ-$(os):
	@echo ">>> Clean XZ build products on $(os)"
	rm -rf \
		build/$(os)/*/xz-$(XZ_VERSION) \
		build/$(os)/*/xz-$(XZ_VERSION).*.log \
		install/$(os)/*/xz-$(XZ_VERSION) \
		install/$(os)/*/xz-$(XZ_VERSION).*.log \
		merge/$(os)/*/xz-$(XZ_VERSION) \
		merge/$(os)/*/xz-$(XZ_VERSION).*.log \
		wheels/dist/xz

clean-XZ-wheels-$(os):
	rm -rf \
		install/$(os)/*/xz-$(XZ_VERSION)/wheel \
		wheels/dist/xz

###########################################################################
# Build: OpenSSL
###########################################################################

OpenSSL-$(os): $$(foreach sdk,$$(SDKS-$(os)),$$(OPENSSL_FATINCLUDE-$$(sdk)) $$(OPENSSL_SSL_FATLIB-$$(sdk)) $$(OPENSSL_CRYPTO_FATLIB-$$(sdk)))
OpenSSL-wheels-$(os): $$(foreach target,$$(TARGETS-$(os)),$$(OPENSSL_WHEEL-$$(target)))

clean-OpenSSL-$(os):
	@echo ">>> Clean OpenSSL build products on $(os)"
	rm -rf \
		build/$(os)/*/openssl-$(OPENSSL_VERSION) \
		build/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		install/$(os)/*/openssl-$(OPENSSL_VERSION) \
		install/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		merge/$(os)/*/openssl-$(OPENSSL_VERSION) \
		merge/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		wheels/dist/openssl

clean-OpenSSL-wheels-$(os):
	rm -rf \
		install/$(os)/*/openssl-$(OPENSSL_VERSION)/wheel \
		wheels/dist/openssl

###########################################################################
# Build: libFFI
###########################################################################

# macOS uses the system-provided libFFI, so there's no need to package
# a libFFI framework for macOS.
ifneq ($(os),macOS)

$$(LIBFFI_SRCDIR-$(os))/darwin_common/include/ffi.h: downloads/libffi-$(LIBFFI_VERSION).tar.gz $(HOST_PYTHON_EXE)
	@echo ">>> Unpack and configure libFFI sources on $(os)"
	mkdir -p $$(LIBFFI_SRCDIR-$(os))
	tar zxf $$< --strip-components 1 -C $$(LIBFFI_SRCDIR-$(os))
	# Patch the build to add support for new platforms
	cd $$(LIBFFI_SRCDIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/libffi-$(LIBFFI_VERSION).patch
	# Configure the build
	cd $$(LIBFFI_SRCDIR-$(os)) && \
		$(PROJECT_DIR)/$(HOST_PYTHON_EXE) generate-darwin-source-and-headers.py --only-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') \
		2>&1 | tee -a ../libffi-$(LIBFFI_VERSION).config.log

endif

libFFI-$(os): $$(foreach sdk,$$(SDKS-$(os)),$$(LIBFFI_FATLIB-$$(sdk)))
libFFI-wheels-$(os): $$(foreach target,$$(TARGETS-$(os)),$$(LIBFFI_WHEEL-$$(target)))

clean-libFFI-$(os):
	@echo ">>> Clean libFFI build products on $(os)"
	rm -rf \
		build/$(os)/libffi-$(LIBFFI_VERSION) \
		build/$(os)/libffi-$(LIBFFI_VERSION).*.log \
		merge/$(os)/libffi-$(LIBFFI_VERSION) \
		merge/$(os)/libffi-$(LIBFFI_VERSION).*.log \
		wheels/dist/libffi

clean-libFFI-wheels-$(os):
	rm -rf \
		build/$(os)/libffi-$(LIBFFI_VERSION)/build_*/wheel \
		wheels/dist/libffi

###########################################################################
# Build: Python
###########################################################################

$$(PYTHON_XCFRAMEWORK-$(os)): \
		$$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_FATLIB-$$(sdk)) $$(PYTHON_FATINCLUDE-$$(sdk)))
	@echo ">>> Create Python.XCFramework on $(os)"
	mkdir -p $$(dir $$(PYTHON_XCFRAMEWORK-$(os)))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(PYTHON_FATLIB-$$(sdk)) -headers $$(PYTHON_FATINCLUDE-$$(sdk))) \
		2>&1 | tee -a support/$(PYTHON_VER)/python-$(os).xcframework.log

$$(PYTHON_STDLIB-$(os)): \
		$$(PYTHON_XCFRAMEWORK-$(os)) \
		$$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_FATSTDLIB-$$(sdk)))
	@echo ">>> Create Python stdlib on $(os)"
	# Copy stdlib from first SDK in $(os)
	cp -r $$(PYTHON_FATSTDLIB-$$(firstword $$(SDKS-$(os)))) $$(PYTHON_STDLIB-$(os))

	# Delete the single-SDK stdlib artefacts from $(os)
	rm -rf \
		$$(PYTHON_STDLIB-$(os))/_sysconfigdata__*.py \
		$$(PYTHON_STDLIB-$(os))/config-* \
		$$(PYTHON_STDLIB-$(os))/lib-dynload/*

	# Copy the config-* contents from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp -r $$(PYTHON_FATSTDLIB-$$(sdk))/config-$(PYTHON_VER)-* $$(PYTHON_STDLIB-$(os)); )

	# Copy the _sysconfigdata modules from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp $$(PYTHON_FATSTDLIB-$$(sdk))/_sysconfigdata__*.py $$(PYTHON_STDLIB-$(os)); )

	# Copy the lib-dynload contents from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp $$(PYTHON_FATSTDLIB-$$(sdk))/lib-dynload/* $$(PYTHON_STDLIB-$(os))/lib-dynload; )

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: $$(PYTHON_XCFRAMEWORK-$(os)) $$(PYTHON_STDLIB-$(os))
	@echo ">>> Create VERSIONS file for $(os)"
	echo "Python version: $(PYTHON_VERSION) " > support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Min $(os) version: $$(VERSION_MIN-$(os))" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "---------------------" >> support/$(PYTHON_VER)/$(os)/VERSIONS
ifeq ($(os),macOS)
	echo "libFFI: macOS native" >> support/$(PYTHON_VER)/$(os)/VERSIONS
else
	echo "libFFI: $(LIBFFI_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
endif
	echo "BZip2: $(BZIP2_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "OpenSSL: $(OPENSSL_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "XZ: $(XZ_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS

ifneq ($(os),macOS)
	@echo ">>> Create cross-platform site sitecustomize.py for $(os)"
	mkdir -p support/$(PYTHON_VER)/$(os)/platform-site
	cat $(PROJECT_DIR)/patch/Python/sitecustomize.py \
		| sed -e "s/{{os}}/$(os)/g" \
		| sed -e "s/{{tag}}/$$(shell echo $(os) | tr '[:upper:]' '[:lower:]')_$$(shell echo $$(VERSION_MIN-$(os)) | sed "s/\./_/g")/g" \
		> support/$(PYTHON_VER)/$(os)/platform-site/sitecustomize.py
endif

	@echo ">>> Create final distribution artefact for $(os)"
	mkdir -p dist
	# Build a "full" tarball with all content for test purposes
	tar zcvf dist/Python-$(PYTHON_VER)-$(os)-support.test-$(BUILD_NUMBER).tar.gz -X patch/Python/test.exclude -C support/$(PYTHON_VER)/$(os) `ls -A support/$(PYTHON_VER)/$(os)/`
	# Build a distributable tarball
	tar zcvf $$@ -X patch/Python/release.common.exclude -X patch/Python/release.$(os).exclude -C support/$(PYTHON_VER)/$(os) `ls -A support/$(PYTHON_VER)/$(os)/`

Python-$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

clean-Python-$(os):
	@echo ">>> Clean Python build products on $(os)"
	rm -rf \
		build/$(os)/*/python-$(PYTHON_VER)* \
		build/$(os)/*/python-$(PYTHON_VER)*.*.log \
		install/$(os)/*/python-$(PYTHON_VER)* \
		install/$(os)/*/python-$(PYTHON_VER)*.*.log \
		merge/$(os)/*/python-$(PYTHON_VER)* \
		merge/$(os)/*/python-$(PYTHON_VER)*.*.log \
		support/$(PYTHON_VER)/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-*

dev-clean-Python-$(os):
	@echo ">>> Partially clean Python build products on $(os) so that local code modifications can be made"
	rm -rf \
		build/$(os)/*/Python-$(PYTHON_VERSION)/python.exe \
		build/$(os)/*/python-$(PYTHON_VERSION).*.log \
		install/$(os)/*/python-$(PYTHON_VERSION) \
		install/$(os)/*/python-$(PYTHON_VERSION).*.log \
		merge/$(os)/*/python-$(PYTHON_VERSION) \
		merge/$(os)/*/python-$(PYTHON_VERSION).*.log \
		support/$(PYTHON_VER)/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-*

merge-clean-Python-$(os):
	@echo ">>> Partially clean Python build products on $(os) so that merge modifications can be made"
	rm -rf \
		merge/$(os)/*/python-$(PYTHON_VERSION) \
		merge/$(os)/*/python-$(PYTHON_VERSION).*.log \
		support/$(PYTHON_VER)/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-*

###########################################################################
# Build
###########################################################################

$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz
$(os)-wheels: $(foreach dep,$(DEPENDENCIES),$(dep)-wheels-$(os))

clean-$(os):
	@echo ">>> Clean $(os) build products"
	rm -rf \
		build/$(os) \
		install/$(os) \
		merge/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz \
		dist/Python-$(PYTHON_VER)-$(os)-support.test-$(BUILD_NUMBER).tar.gz \

clean-wheels-$(os): $(foreach dep,$(DEPENDENCIES),clean-$(dep)-wheels-$(os))

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo "LIBFFI_SRCDIR-$(os): $$(LIBFFI_SRCDIR-$(os))"
	@echo "LIBPYTHON_XCFRAMEWORK-$(os): $$(LIBPYTHON_XCFRAMEWORK-$(os))"
	@echo "PYTHON_XCFRAMEWORK-$(os): $$(PYTHON_XCFRAMEWORK-$(os))"
	@echo

endef # build

$(BDIST_WHEEL): $(HOST_PYTHON_EXE)
	@echo ">>> Ensure the macOS python install has pip and wheel"
	$(HOST_PYTHON_EXE) -m ensurepip
	PIP_REQUIRE_VIRTUALENV=false $(HOST_PYTHON_EXE) -m pip install wheel

# Binary support wheels
wheels: $(foreach dep,$(DEPENDENCIES),$(dep)-wheels)
clean-wheels: $(foreach dep,$(DEPENDENCIES),clean-wheels-$(dep))

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand cross-platform build and clean targets for each output product
BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
BZip2-wheels: $(foreach os,$(OS_LIST),BZip2-wheels-$(os))
clean-BZip2: $(foreach os,$(OS_LIST),clean-BZip2-$(os))
clean-BZip2-wheels: $(foreach os,$(OS_LIST),clean-BZip2-wheels-$(os))

XZ: $(foreach os,$(OS_LIST),XZ-$(os))
XZ-wheels: $(foreach os,$(OS_LIST),XZ-wheels-$(os))
clean-XZ: $(foreach os,$(OS_LIST),clean-XZ-$(os))
clean-XZ-wheels: $(foreach os,$(OS_LIST),clean-XZ-wheels-$(os))

OpenSSL: $(foreach os,$(OS_LIST),OpenSSL-$(os))
OpenSSL-wheels: $(foreach os,$(OS_LIST),OpenSSL-wheels-$(os))
clean-OpenSSL: $(foreach os,$(OS_LIST),clean-OpenSSL-$(os))
clean-OpenSSL-wheels: $(foreach os,$(OS_LIST),clean-OpenSSL-wheels-$(os))

libFFI: $(foreach os,$(OS_LIST),libFFI-$(os))
libFFI-wheels: $(foreach os,$(OS_LIST),libFFI-wheels-$(os))
clean-libFFI: $(foreach os,$(OS_LIST),clean-libFFI-$(os))
clean-libFFI-wheels: $(foreach os,$(OS_LIST),clean-libFFI-wheels-$(os))

Python: $(foreach os,$(OS_LIST),Python-$(os))
clean-Python: $(foreach os,$(OS_LIST),clean-Python-$(os))
dev-clean-Python: $(foreach os,$(OS_LIST),dev-clean-Python-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
