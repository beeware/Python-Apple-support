#
# Useful targets:
# - all             - build everything
# - macOS           - build everything for macOS
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS
# - OpenSSL         - build OpenSSL for all platforms
# - OpenSSL-macOS   - build OpenSSL for macOS
# - OpenSSL-iOS     - build OpenSSL for iOS
# - OpenSSL-tvOS    - build OpenSSL for tvOS
# - OpenSSL-watchOS - build OpenSSL for watchOS
# - BZip2           - build Bzip2 for all platforms
# - BZip2-macOS     - build BZip2 for macOS
# - BZip2-iOS       - build BZip2 for iOS
# - BZip2-tvOS      - build BZip2 for tvOS
# - BZip2-watchOS   - build BZip2 for watchOS
# - XZ              - build XZ for all platforms
# - XZ-macOS        - build XZ for macOS
# - XZ-iOS          - build XZ for iOS
# - XZ-tvOS         - build XZ for tvOS
# - XZ-watchOS      - build XZ for watchOS
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

# This version limit will only be honored on x86_64 builds.
# arm64/M1 builds are only supporteded on macOS 11.0 or greater.
MACOSX_DEPLOYMENT_TARGET-x86_64=10.8
MACOSX_DEPLOYMENT_TARGET-arm64=11.0

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
OS_LIST=macOS iOS tvOS watchOS

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
PYTHON_TARGETS-macOS=macOS
CFLAGS-macOS=
CFLAGS-macosx.x86_64=-mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET-x86_64)
CFLAGS-macosx.arm64=-mmacosx-version-min=$(MACOSX_DEPLOYMENT_TARGET-arm64)

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64
CFLAGS-iOS=-mios-version-min=13.0 -fembed-bitcode
CFLAGS-iphoneos.arm64=
CFLAGS-iphonesimulator.x86_64=
CFLAGS-iphonesimulator.arm64=

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvsimulator.arm64 appletvos.arm64
CFLAGS-tvOS=-mtvos-version-min=9.0 -fembed-bitcode
CFLAGS-appletvos.arm64=
CFLAGS-appletvsimulator.x86_64=
CFLAGS-appletvsimulator.arm64=
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.x86_64 watchsimulator.arm64 watchos.arm64_32
CFLAGS-watchOS=-mwatchos-version-min=4.0 -fembed-bitcode
CFLAGS_watchsimulator.x86_64=
CFLAGS-watchsimulator.arm64=
CFLAGS-watchos.arm64_32=
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

# override machine types for arm64
MACHINE_DETAILED-arm64=aarch64
MACHINE_SIMPLE-arm64=arm

# override machine types for arm64_32
MACHINE_DETAILED-arm64_32=aarch64
MACHINE_SIMPLE-arm64_32=arm

# Build for all operating systems
all: $(OS_LIST)

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
# Setup: OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	@echo ">>> Clean OpenSSL build products"
	rm -rf build/*/openssl-$(OPENSSL_VERSION)-* \
		build/*/openssl \
		build/*/openssl-*.log \
		build/*/Support/OpenSSL.xcframework

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	@echo ">>> Download OpenSSL sources"
	mkdir -p downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi

###########################################################################
# Setup: BZip2
###########################################################################

# Clean the bzip2 project
clean-BZip2:
	@echo ">>> Clean BZip2 build products"
	rm -rf build/*/bzip2-$(BZIP2_VERSION)-* \
		build/*/bzip2 \
		build/*/bzip2-*.log \
		build/*/Support/BZip2.xcframework

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tgz:
	@echo ">>> Download BZip2 sources"
	mkdir -p downloads
	if [ ! -e downloads/bzip2-$(BZIP2_VERSION).tgz ]; then curl --fail -L https://sourceware.org/pub/bzip2/bzip2-$(BZIP2_VERSION).tar.gz -o downloads/bzip2-$(BZIP2_VERSION).tgz; fi

###########################################################################
# Setup: XZ (LZMA)
###########################################################################

# Clean the XZ project
clean-XZ:
	@echo ">>> Clean XZ build products"
	rm -rf build/*/xz-$(XZ_VERSION)-* \
		build/*/xz \
		build/*/xz-*.log \
		build/*/Support/XZ.xcframework

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tgz:
	@echo ">>> Download XZ sources"
	mkdir -p downloads
	if [ ! -e downloads/xz-$(XZ_VERSION).tgz ]; then curl --fail -L http://tukaani.org/xz/xz-$(XZ_VERSION).tar.gz -o downloads/xz-$(XZ_VERSION).tgz; fi

###########################################################################
# Setup: libFFI
###########################################################################

# Clean the LibFFI project
clean-libFFI:
	@echo ">>> Clean libFFI build products"
	rm -rf build/*/libffi-$(LIBFFI_VERSION) \
		build/*/libffi-*.log \
		build/*/Support/libFFI.xcframework

# Download original XZ source code archive.
downloads/libffi-$(LIBFFI_VERSION).tgz:
	@echo ">>> Download libFFI sources"
	mkdir -p downloads
	if [ ! -e downloads/libffi-$(LIBFFI_VERSION).tgz ]; then curl --fail -L http://github.com/libffi/libffi/releases/download/v$(LIBFFI_VERSION)/libffi-$(LIBFFI_VERSION).tar.gz -o downloads/libffi-$(LIBFFI_VERSION).tgz; fi

###########################################################################
# Setup: Python
###########################################################################

# Clean the Python project
clean-Python:
	@echo ">>> Clean Python build products"
	rm -rf \
		build/*/Python-$(PYTHON_VERSION)-* \
		build/*/libpython$(PYTHON_VER).a \
		build/*/pyconfig-*.h \
		build/*/Support/Python

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	@echo ">>> Download Python sources"
	mkdir -p downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_MICRO_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

# Some Python targets needed to identify the host build
PYTHON_DIR-macOS=build/macOS/Python-$(PYTHON_VERSION)-macOS
PYTHON_HOST=$(PYTHON_DIR-macOS)/dist/lib/libpython$(PYTHON_VER).a

# Build for specified target (from $(TARGETS-*))
#
# Parameters:
# - $1 - target (e.g., iphonesimulator.x86_64, iphoneos.arm64)
# - $2 - OS (e.g., iOS, tvOS)
define build-target
target=$1
os=$2

# $(target) can be broken up into is composed of $(SDK).$(ARCH)
SDK-$(target)=$$(basename $(target))
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

ifeq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$(shell echo $(os) | tr '[:upper:]' '[:lower:]')
else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$(shell echo $(os) | tr '[:upper:]' '[:lower:]')-simulator
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang \
	-target $$(TARGET_TRIPLE-$(target)) \
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os)) $$(CFLAGS-$(target))
LDFLAGS-$(target)=-arch $$(ARCH-$(target)) -isysroot=$$(SDK_ROOT-$(target))

###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_DIR-$(target)=build/$(os)/openssl-$(OPENSSL_VERSION)-$(target)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_DIR-$(target))/_install/lib/libssl.a
OPENSSL_CRYPTO_LIB-$(target)=$$(OPENSSL_DIR-$(target))/_install/lib/libcrypto.a

$$(OPENSSL_DIR-$(target))/Makefile: downloads/openssl-$(OPENSSL_VERSION).tgz
	@echo ">>> Unpack and configure OpenSSL sources for $(target)"
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

	# Configure the OpenSSL build
ifeq ($(os),macOS)
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET-$$(ARCH-$(target))) \
		./Configure darwin64-$$(ARCH-$(target))-cc no-tests \
			--prefix="$(PROJECT_DIR)/$$(OPENSSL_DIR-$(target))/_install" \
			--openssldir=/etc/ssl \
			2>&1 | tee ../openssl-$(target).config.log
else
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		./Configure iphoneos-cross no-asm no-tests \
			--prefix="$(PROJECT_DIR)/$$(OPENSSL_DIR-$(target))/_install" \
			--openssldir=/etc/ssl \
			2>&1 | tee ../openssl-$(target).config.log

endif

$$(OPENSSL_SSL_LIB-$(target)) $$(OPENSSL_CRYPTO_LIB-$(target)): $$(OPENSSL_DIR-$(target))/Makefile
	@echo ">>> Build and install OpenSSL for $(target)"
	# Make and install just the software (not the docs)
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make install_sw \
			2>&1 | tee ../openssl-$(target).build.log

###########################################################################
# Target: BZip2
###########################################################################

BZIP2_DIR-$(target)=build/$(os)/bzip2-$(BZIP2_VERSION)-$(target)
BZIP2_LIB-$(target)=$$(BZIP2_DIR-$(target))/_install/lib/libbz2.a

$$(BZIP2_DIR-$(target))/Makefile: downloads/bzip2-$(BZIP2_VERSION).tgz
	@echo ">>> Unpack BZip2 sources for $(target)"
	mkdir -p $$(BZIP2_DIR-$(target))
	tar zxf downloads/bzip2-$(BZIP2_VERSION).tgz --strip-components 1 -C $$(BZIP2_DIR-$(target))
	# Touch the makefile to ensure that Make identifies it as up to date.
	touch $$(BZIP2_DIR-$(target))/Makefile

$$(BZIP2_LIB-$(target)): $$(BZIP2_DIR-$(target))/Makefile
	@echo ">>> Build BZip2 for $(target)"
	cd $$(BZIP2_DIR-$(target)) && \
		make install \
			PREFIX="$(PROJECT_DIR)/$$(BZIP2_DIR-$(target))/_install" \
			CC="$$(CC-$(target))" \
			2>&1 | tee ../bzip2-$(target).build.log

###########################################################################
# Target: XZ (LZMA)
###########################################################################

XZ_DIR-$(target)=build/$(os)/xz-$(XZ_VERSION)-$(target)
XZ_LIB-$(target)=$$(XZ_DIR-$(target))/_install/lib/liblzma.a

$$(XZ_DIR-$(target))/Makefile: downloads/xz-$(XZ_VERSION).tgz
	@echo ">>> Unpack XZ sources for $(target)"
	mkdir -p $$(XZ_DIR-$(target))
	tar zxf downloads/xz-$(XZ_VERSION).tgz --strip-components 1 -C $$(XZ_DIR-$(target))
	# Configure the build
	cd $$(XZ_DIR-$(target)) && \
		MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET-$$(ARCH-$(target))) \
		./configure \
			CC="$$(CC-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared --enable-static \
			--host=$$(MACHINE_SIMPLE-$(target))-apple-darwin \
			--prefix="$(PROJECT_DIR)/$$(XZ_DIR-$(target))/_install" \
			2>&1 | tee ../xz-$(target).config.log

$$(XZ_LIB-$(target)): $$(XZ_DIR-$(target))/Makefile
	@echo ">>> Build and install XZ for $(target)"
	cd $$(XZ_DIR-$(target)) && \
		make install \
			2>&1 | tee ../xz-$(target).build.log

###########################################################################
# Target: libFFI
###########################################################################

# macOS builds use the system libFFI, so there's no need to do
# a per-target build on macOS
ifneq ($(os),macOS)

LIBFFI_DIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)
LIBFFI_DIR-$(target)=$$(LIBFFI_DIR-$(os))/build_$$(SDK-$(target))-$$(ARCH-$(target))
LIBFFI_LIB-$(target)=$$(LIBFFI_DIR-$(target))/.libs/libffi.a

$$(LIBFFI_LIB-$(target)): $$(LIBFFI_DIR-$(os))/darwin_common
	@echo ">>> Build libFFI for $(target)"
	cd $$(LIBFFI_DIR-$(target)) && \
		make \
			2>&1 | tee ../../libffi-$(target).build.log

endif

###########################################################################
# Target: Python
###########################################################################

# macOS builds are compiled as a single universal2 build. As a result,
# the macOS Python build is configured in the `build` macro, rather than the
# `build-target` macro.
ifneq ($(os),macOS)

PYTHON_DIR-$(target)=build/$(os)/Python-$(PYTHON_VERSION)-$(target)
pyconfig.h-$(target)=pyconfig-$$(ARCH-$(target)).h
PYTHON_HOST-$(target)=$(PYTHON_HOST)

# Unpack Python
$$(PYTHON_DIR-$(target))/Makefile: downloads/Python-$(PYTHON_VERSION).tgz $$(PYTHON_HOST-$(target))
	@echo ">>> Unpack and configure Python for $(target)"
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
		--prefix="$(PROJECT_DIR)/$$(PYTHON_DIR-$(target))/dist" \
		--without-doc-strings --enable-ipv6 --without-ensurepip \
		ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
		$$(PYTHON_CONFIGURE-$(os))

# Build Python
$$(PYTHON_DIR-$(target))/dist/lib/libpython$(PYTHON_VER).a: build/$(os)/Support/OpenSSL build/$(os)/Support/BZip2 build/$(os)/Support/XZ build/$(os)/Support/libFFI $$(PYTHON_DIR-$(target))/Makefile
	@echo ">>> Build Python for $(target)"
	cd $$(PYTHON_DIR-$(target)) && PATH="$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH)" make all install

endif

###########################################################################
# Target: Debug
###########################################################################

vars-$(target):
	@echo ">>> Environment variables for $(target)"
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "MACHINE_DETAILED-$(target): $$(MACHINE_DETAILED-$(target))"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CC-$(target): $$(CC-$(target))"
	@echo "OPENSSL_DIR-$(target): $$(OPENSSL_DIR-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "OPENSSL_CRYPTO_LIB-$(target): $$(OPENSSL_CRYPTO_LIB-$(target))"
	@echo "BZIP2_DIR-$(target): $$(BZIP2_DIR-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "XZ_DIR-$(target): $$(XZ_DIR-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "LIBFFI_DIR-$(target): $$(LIBFFI_DIR-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
	@echo "PYTHON_DIR-$(target): $$(PYTHON_DIR-$(target))"
	@echo "pyconfig.h-$(target): $$(pyconfig.h-$(target))"
	@echo

endef # build-target

# Build for specified architecture (extracted from the suffixes in $(TARGETS-*))
#
# Parameters:
# - $1 architecture (e.g., x86_64, arm64)
# - $2 OS (e.g., iOS, tvOS)
define build-arch
arch=$1
os=$2

###########################################################################
# Arch: Python
###########################################################################

build/$(os)/pyconfig.h-$(arch): $$(PYTHON_DIR-$(arch))/dist/include/python$(PYTHON_VER)/pyconfig.h
	@echo ">>> Install pyconfig.h for $(arch) on $(os)"
	cp -f $$^ $$@

###########################################################################
# Arch: Debug
###########################################################################

vars-$(arch):

endef # build-arch

# Build for specified sdk (extracted from the base names in $(TARGETS-*))
#
# Parameters:
# - $1 sdk (e.g., iphoneos, iphonesimulator)
# - $2 OS (e.g., iOS, tvOS)
define build-sdk
sdk=$1
os=$2

SDK_TARGETS-$(sdk)=$$(filter $(sdk).%,$$(TARGETS-$(os)))
SDK_ARCHES-$(sdk)=$$(sort $$(subst .,,$$(suffix $$(SDK_TARGETS-$(sdk)))))

###########################################################################
# SDK: OpenSSL
###########################################################################

OPENSSL_FATLIB-$(sdk)=build/$(os)/openssl/$(sdk)/lib/libopenssl.a

$$(OPENSSL_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)) $$(OPENSSL_CRYPTO_LIB-$$(target)))
	@echo ">>> Build OpenSSL fat library for $(sdk)"
	mkdir -p build/$(os)/openssl/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -static -o $$@ $$^
	# Copy headers from the first target associated with the SDK
	cp -r $$(OPENSSL_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/openssl/$(sdk)

###########################################################################
# SDK: BZip2
###########################################################################

BZIP2_FATLIB-$(sdk)=build/$(os)/bzip2/$(sdk)/lib/libbz2.a

$$(BZIP2_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(BZIP2_LIB-$$(target)))
	@echo ">>> Build BZip2 fat library for $(sdk)"
	mkdir -p build/$(os)/bzip2/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -static -o $$@ $$^
	# Copy headers from the first target associated with the SDK
	cp -r $$(BZIP2_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/bzip2/$(sdk)

###########################################################################
# SDK: XZ (LZMA)
###########################################################################

XZ_FATLIB-$(sdk)=build/$(os)/xz/$(sdk)/lib/liblzma.a

$$(XZ_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(XZ_LIB-$$(target)))
	@echo ">>> Build XZ fat library for $(sdk)"
	mkdir -p build/$(os)/xz/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -static -o $$@ $$^
	# Copy headers from the first target associated with the SDK
	cp -r $$(XZ_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/xz/$(sdk)

###########################################################################
# SDK: LibFFI
###########################################################################

LIBFFI_FATLIB-$(sdk)=$$(LIBFFI_DIR-$(os))/_install/$(sdk)/libffi.a

test-$(sdk):
	# $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(LIBFFI_LIB-$$(target)))

$$(LIBFFI_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(LIBFFI_LIB-$$(target)))
	@echo ">>> Build LibFFI fat library for $(sdk)"
	mkdir -p $$(LIBFFI_DIR-$(os))/_install/$(sdk)
	xcrun --sdk $(sdk) libtool -static -o $$@ $$^
	# Copy headers from the first target associated with the SDK
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_common/include \
		$$(LIBFFI_DIR-$(os))/_install/$(sdk)
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_$(shell echo $(os) | tr '[:upper:]' '[:lower:]')/include/* \
		$$(LIBFFI_DIR-$(os))/_install/$(sdk)/include

###########################################################################
# SDK: Debug
###########################################################################

vars-$(sdk):
	@echo ">>> Environment variables for $(sdk)"
	@echo "SDK_TARGETS-$(sdk): $$(SDK_TARGETS-$(sdk))"
	@echo "SDK_ARCHES-$(sdk): $$(SDK_ARCHES-$(sdk))"
	@echo "BZIP2_FATLIB-$(sdk): $$(BZIP2_FATLIB-$(sdk))"
	@echo "XZ_FATLIB-$(sdk): $$(XZ_FATLIB-$(sdk))"
	@echo "OPENSSL_FATLIB-$(sdk): $$(OPENSSL_FATLIB-$(sdk))"
	@echo "LIBFFI_FATLIB-$(sdk): $$(LIBFFI_FATLIB-$(sdk))"
	@echo

endef # build-sdk

# Build for specified OS (from $(OS_LIST))
#
# Parameters:
# - $1 - OS (e.g., iOS, tvOS)
define build
os=$1


###########################################################################
# Build: Macro Expansions
###########################################################################

# Expand the build-target macro for target on this OS
$$(foreach target,$$(TARGETS-$(os)),$$(eval $$(call build-target,$$(target),$(os))))

# Expand the build-arch macro for all architectures on this OS.
ARCHES-$(os)=$$(sort $$(subst .,,$$(suffix $$(TARGETS-$(os)))))
$$(foreach arch,$$(ARCHES-$(os)),$$(eval $$(call build-arch,$$(arch),$(os))))

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: OpenSSL
###########################################################################

OPENSSL_XCFRAMEWORK-$(os)=build/$(os)/Support/OpenSSL.xcframework

$$(OPENSSL_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(OPENSSL_FATLIB-$$(sdk)))
	@echo ">>> Create OpenSSL.XCFramework on $(os)"
	mkdir -p $$(OPENSSL_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(OPENSSL_FATLIB-$$(sdk)) -headers build/$(os)/openssl/$$(sdk)/include)

OpenSSL-$(os): $$(OPENSSL_XCFRAMEWORK-$(os))

###########################################################################
# Build: BZip2
###########################################################################

BZIP2_XCFRAMEWORK-$(os)=build/$(os)/Support/BZip2.xcframework

$$(BZIP2_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(BZIP2_FATLIB-$$(sdk)))
	@echo ">>> Create BZip2.XCFramework on $(os)"
	mkdir -p $$(BZIP2_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(BZIP2_FATLIB-$$(sdk)) -headers build/$(os)/bzip2/$$(sdk)/include)

BZip2-$(os): $$(BZIP2_XCFRAMEWORK-$(os))

###########################################################################
# Build: XZ (LZMA)
###########################################################################

XZ_XCFRAMEWORK-$(os)=build/$(os)/Support/XZ.xcframework

$$(XZ_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(XZ_FATLIB-$$(sdk)))
	@echo ">>> Create XZ.XCFramework on $(os)"
	mkdir -p $$(XZ_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(XZ_FATLIB-$$(sdk)) -headers build/$(os)/xz/$$(sdk)/include)

XZ-$(os): $$(XZ_XCFRAMEWORK-$(os))

###########################################################################
# Build: libFFI
###########################################################################

LIBFFI_XCFRAMEWORK-$(os)=build/$(os)/Support/libFFI.xcframework

# macOS uses the system-provided libFFI, so there's no need to package
# a libFFI framework for macOS.
ifeq ($(os),macOS)
# There's no XCFramework needed for macOS; we declare an empty target
# so that expansions don't complain about missing targets
$$(LIBFFI_XCFRAMEWORK-$(os)):

else

LIBFFI_DIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)

# Unpack LibFFI and generate source & headers
$$(LIBFFI_DIR-$(os))/darwin_common: downloads/libffi-$(LIBFFI_VERSION).tgz
	@echo ">>> Unpack and configure libFFI sources on $(os)"
	mkdir -p $$(LIBFFI_DIR-$(os))
	tar zxf downloads/libffi-$(LIBFFI_VERSION).tgz --strip-components 1 -C $$(LIBFFI_DIR-$(os))
	# Patch the build to add support for new platforms
	cd $$(LIBFFI_DIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/libffi.patch
	# Configure the build
	cd $$(LIBFFI_DIR-$(os)) && \
		python generate-darwin-source-and-headers.py --only-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') \
		2>&1 | tee ../libffi-$(os).config.log

$$(LIBFFI_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(LIBFFI_FATLIB-$$(sdk)))
	@echo ">>> Create libFFI.XCFramework on $(os)"
	mkdir -p $$(LIBFFI_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(LIBFFI_FATLIB-$$(sdk)) -headers $$(LIBFFI_DIR-$(os))/_install/$$(sdk)/include)

endif

libFFI-$(os): $$(LIBFFI_XCFRAMEWORK-$(os))

###########################################################################
# Build: Python
###########################################################################

PYTHON_FRAMEWORK-$(os)=build/$(os)/Support/Python
PYTHON_RESOURCES-$(os)=$$(PYTHON_FRAMEWORK-$(os))/Resources

# macOS builds a single Python universal2 target; thus it needs to be
# configured in the `build` macro, not the `build-target` macro.
ifeq ($(os),macOS)

$$(PYTHON_DIR-$(os))/Makefile: downloads/Python-$(PYTHON_VERSION).tgz
	@echo ">>> Unpack and configure Python on $(os)"
	mkdir -p $$(PYTHON_DIR-$(os))
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$(os))
	# Apply target Python patches
	cd $$(PYTHON_DIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Copy in the embedded module configuration
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded $(PROJECT_DIR)/patch/Python/Setup.$(os) > $$(PYTHON_DIR-$(os))/Modules/Setup.local
	# Configure target Python
	cd $$(PYTHON_DIR-$(os)) &&
		MACOSX_DEPLOYMENT_TARGET=$$(MACOSX_DEPLOYMENT_TARGET-$$(ARCH-$(target))) \
		./configure \
			--prefix="$(PROJECT_DIR)/$$(PYTHON_DIR-$(os))/dist" \
			--without-doc-strings --enable-ipv6 --without-ensurepip --enable-universalsdk --with-universal-archs=universal2 \
			$$(PYTHON_CONFIGURE-$(os))

$$(PYTHON_DIR-$(os))/dist/lib/libpython$(PYTHON_VER).a: $$(BZIP2_XCFRAMEWORK-$(os)) $$(XZ_XCFRAMEWORK-$(os)) $$(OPENSSL_XCFRAMEWORK-$(os)) $$(LIBFFI_XCFRAMEWORK-$(os))  $$(PYTHON_DIR-$(os))/Makefile
	@echo ">>> Build and install Python for $(os)"
	cd $$(PYTHON_DIR-$(os)) && PATH="$(PROJECT_DIR)/$(PYTHON_DIR-$(os))/dist/bin:$(PATH)" make all install

else
# The Python targets are the same as they are for every other library
PYTHON_TARGETS-$(os)=$$(TARGETS-$(os))

endif

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

###########################################################################
# Build
###########################################################################

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: $$(BZIP2_XCFRAMEWORK-$(os)) $$(XZ_XCFRAMEWORK-$(os)) $$(OPENSSL_XCFRAMEWORK-$(os)) $$(LIBFFI_XCFRAMEWORK-$(os)) $$(PYTHON_FRAMEWORK-$(os))
	@echo ">>> Create final distribution artefact for $(os)"
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

$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

clean-$(os):
	@echo ">>> Clean $(os) build products"
	rm -rf build/$(os)

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach arch,$$(ARCHES-$(os)),vars-$$(arch)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "ARCHES-$(os): $$(ARCHES-$(os))"
	@echo "OPENSSL_XCFRAMEWORK-$(os): $$(OPENSSL_XCFRAMEWORK-$(os))"
	@echo "BZIP2_XCFRAMEWORK-$(os): $$(BZIP2_XCFRAMEWORK-$(os))"
	@echo "XZ_XCFRAMEWORK-$(os): $$(XZ_XCFRAMEWORK-$(os))"
	@echo "LIBFFI_XCFRAMEWORK-$(os): $$(LIBFFI_XCFRAMEWORK-$(os))"
	@echo "PYTHON_FRAMEWORK-$(os): $$(PYTHON_FRAMEWORK-$(os))"
	@echo "LIBFFI_DIR-$(os): $$(LIBFFI_DIR-$(os))"
	@echo "PYTHON_RESOURCES-$(os): $$(PYTHON_RESOURCES-$(os))"
	@echo "PYTHON_TARGETS-$(os): $$(PYTHON_TARGETS-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand cross-platform build targets for each library
XZ: $(foreach os,$(OS_LIST),XZ-$(os))
BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
OpenSSL: $(foreach os,$(OS_LIST),OpenSSL-$(os))
libFFI: $(foreach os,$(OS_LIST),libFFI-$(os))
Python: $(foreach os,$(OS_LIST),Python-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
