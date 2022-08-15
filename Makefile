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
PYTHON_VERSION=3.11.0b5
PYTHON_MICRO_VERSION=$(shell echo $(PYTHON_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_VER=$(basename $(PYTHON_VERSION))

BZIP2_VERSION=1.0.8

XZ_VERSION=5.2.5

OPENSSL_VERSION_NUMBER=1.1.1
OPENSSL_REVISION=q
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

LIBFFI_VERSION=3.4.2

# Supported OS and products
PRODUCTS=BZip2 XZ OpenSSL libFFI Python
OS_LIST=macOS iOS tvOS watchOS

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
CFLAGS-macOS=-mmacosx-version-min=10.15
CFLAGS-macosx.x86_64=
CFLAGS-macosx.arm64=
SLICE-macosx=macos-arm64_x86_64
SDK_ROOT-macosx=$(shell xcrun --sdk macosx --show-sdk-path)
CC-macosx=xcrun --sdk macosx clang --sysroot=$(SDK_ROOT-macosx) $(CFLAGS-macOS)

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64
CFLAGS-iOS=-mios-version-min=12.0 -fembed-bitcode
CFLAGS-iphoneos.arm64=
CFLAGS-iphonesimulator.x86_64=
CFLAGS-iphonesimulator.arm64=
SLICE-iphoneos=ios-arm64
SLICE-iphonesimulator=ios-arm64_x86_64-simulator

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvsimulator.arm64 appletvos.arm64
CFLAGS-tvOS=-mtvos-version-min=9.0 -fembed-bitcode
CFLAGS-appletvos.arm64=
CFLAGS-appletvsimulator.x86_64=
CFLAGS-appletvsimulator.arm64=
SLICE-appletvos=tvos-arm64
SLICE-appletvsimulator=tvos-arm64_x86_64-simulator
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.x86_64 watchsimulator.arm64 watchos.arm64_32
CFLAGS-watchOS=-mwatchos-version-min=4.0 -fembed-bitcode
CFLAGS_watchsimulator.x86_64=
CFLAGS-watchsimulator.arm64=
CFLAGS-watchos.arm64_32=
SLICE-watchos=watchos-arm64_32
SLICE-watchsimulator=watchos-arm64_x86_64-simulator
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

# override machine types for arm64
MACHINE_DETAILED-arm64=aarch64
MACHINE_SIMPLE-arm64=arm

# override machine types for arm64_32
MACHINE_DETAILED-arm64_32=aarch64
MACHINE_SIMPLE-arm64_32=arm

# The architecture of the machine doing the build
HOST_ARCH=$(shell uname -m)

# Force the path to be minimal. This ensures that anything in the user environment
# (in particular, homebrew and user-provided Python installs) aren't inadvertently
# linked into the support package.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

# Build for all operating systems
all: $(OS_LIST)

.PHONY: \
	all clean distclean update-patch vars \
	$(foreach product,$(PRODUCTS),$(foreach os,$(OS_LIST),$(product) $(product)-$(os) clean-$(product) clean-$(product)-$(os))) \
	$(foreach os,$(OS_LIST),$(os) clean-$(os) vars-$(os))

# Clean all builds
clean:
	rm -rf build dist

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

downloads: \
		downloads/bzip2-$(BZIP2_VERSION).tgz \
		downloads/xz-$(XZ_VERSION).tgz \
		downloads/openssl-$(OPENSSL_VERSION).tgz \
		downloads/libffi-$(LIBFFI_VERSION).tgz \
		downloads/Python-$(PYTHON_VERSION).tgz

update-patch:
	# Generate a diff from the clone of the python/cpython Github repository
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
downloads/bzip2-$(BZIP2_VERSION).tgz:
	@echo ">>> Download BZip2 sources"
	mkdir -p downloads
	if [ ! -e downloads/bzip2-$(BZIP2_VERSION).tgz ]; then \
		curl --fail -L https://sourceware.org/pub/bzip2/bzip2-$(BZIP2_VERSION).tar.gz \
			-o downloads/bzip2-$(BZIP2_VERSION).tgz; \
	fi

###########################################################################
# Setup: XZ (LZMA)
###########################################################################

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tgz:
	@echo ">>> Download XZ sources"
	mkdir -p downloads
	if [ ! -e downloads/xz-$(XZ_VERSION).tgz ]; then \
		curl --fail -L http://tukaani.org/xz/xz-$(XZ_VERSION).tar.gz \
			-o downloads/xz-$(XZ_VERSION).tgz; \
	fi

###########################################################################
# Setup: OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	@echo ">>> Download OpenSSL sources"
	mkdir -p downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then \
		curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz \
			-o downloads/openssl-$(OPENSSL_VERSION).tgz; \
	fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then \
		curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz \
			-o downloads/openssl-$(OPENSSL_VERSION).tgz; \
	fi

###########################################################################
# Setup: libFFI
###########################################################################

# Download original XZ source code archive.
downloads/libffi-$(LIBFFI_VERSION).tgz:
	@echo ">>> Download libFFI sources"
	mkdir -p downloads
	if [ ! -e downloads/libffi-$(LIBFFI_VERSION).tgz ]; then \
		curl --fail -L http://github.com/libffi/libffi/releases/download/v$(LIBFFI_VERSION)/libffi-$(LIBFFI_VERSION).tar.gz \
			-o downloads/libffi-$(LIBFFI_VERSION).tgz; \
	fi

###########################################################################
# Setup: Python
###########################################################################

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	@echo ">>> Download Python sources"
	mkdir -p downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then \
		curl --fail -L https://www.python.org/ftp/python/$(PYTHON_MICRO_VERSION)/Python-$(PYTHON_VERSION).tgz \
			-o downloads/Python-$(PYTHON_VERSION).tgz; \
	fi

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
			2>&1 | tee -a ../bzip2-$(target).build.log

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
		./configure \
			CC="$$(CC-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared --enable-static \
			--host=$$(MACHINE_SIMPLE-$(target))-apple-darwin \
			--prefix="$(PROJECT_DIR)/$$(XZ_DIR-$(target))/_install" \
			2>&1 | tee -a ../xz-$(target).config.log

$$(XZ_LIB-$(target)): $$(XZ_DIR-$(target))/Makefile
	@echo ">>> Build and install XZ for $(target)"
	cd $$(XZ_DIR-$(target)) && \
		make install \
			2>&1 | tee -a ../xz-$(target).build.log

###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_DIR-$(target)=build/$(os)/openssl-$(OPENSSL_VERSION)-$(target)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_DIR-$(target))/_install/lib/libssl.a
OPENSSL_CRYPTO_LIB-$(target)=$$(OPENSSL_DIR-$(target))/_install/lib/libcrypto.a

$$(OPENSSL_DIR-$(target))/is_configured: downloads/openssl-$(OPENSSL_VERSION).tgz
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
		./Configure darwin64-$$(ARCH-$(target))-cc no-tests \
			--prefix="$(PROJECT_DIR)/$$(OPENSSL_DIR-$(target))/_install" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(target).config.log
else
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		./Configure iphoneos-cross no-asm no-tests \
			--prefix="$(PROJECT_DIR)/$$(OPENSSL_DIR-$(target))/_install" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(target).config.log
endif
	# The OpenSSL Makefile is... interesting. Invoking `make all` or `make
	# install` *modifies the Makefile*. Therefore, we can't use the Makefile as
	# a build dependency, because building/installing dirties the target that
	# was used as a dependency. To compensate, create a dummy file as a marker
	# for whether OpenSSL has been configured, and use *that* as a reference.
	date > $$(OPENSSL_DIR-$(target))/is_configured

$$(OPENSSL_DIR-$(target))/libssl.a: $$(OPENSSL_DIR-$(target))/is_configured
	@echo ">>> Build OpenSSL for $(target)"
	# OpenSSL's `all` target modifies the Makefile;
	# use the raw targets that make up all and it's dependencies
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make all \
			2>&1 | tee -a ../openssl-$(target).build.log

$$(OPENSSL_SSL_LIB-$(target)): $$(OPENSSL_DIR-$(target))/libssl.a
	@echo ">>> Install OpenSSL for $(target)"
	# Install just the software (not the docs)
	cd $$(OPENSSL_DIR-$(target)) && \
		CC="$$(CC-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make install_sw \
			2>&1 | tee -a ../openssl-$(target).install.log

###########################################################################
# Target: libFFI
###########################################################################

# macOS builds use the system libFFI, so there's no need to do
# a per-target build on macOS
ifneq ($(os),macOS)

LIBFFI_DIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)
LIBFFI_DIR-$(target)=$$(LIBFFI_DIR-$(os))/build_$$(SDK-$(target))-$$(ARCH-$(target))
LIBFFI_LIB-$(target)=$$(LIBFFI_DIR-$(target))/.libs/libffi.a

$$(LIBFFI_LIB-$(target)): $$(LIBFFI_DIR-$(os))/darwin_common/include/ffi.h
	@echo ">>> Build libFFI for $(target)"
	cd $$(LIBFFI_DIR-$(target)) && \
		make \
			2>&1 | tee -a ../../libffi-$(target).build.log

endif

###########################################################################
# Target: Python
###########################################################################

# macOS builds are compiled as a single universal2 build. As a result,
# the macOS Python build is configured in the `build` macro, rather than the
# `build-target` macro.
ifeq ($(os),macOS)

# These constants will be the same for all macOS targets
PYTHON_DIR-$(target)=build/$(os)/Python-$(PYTHON_VERSION)-$(os)
PYTHON_LIB-$(target)=$$(PYTHON_DIR-$(target))/_install/lib/libpython$(PYTHON_VER).a
# PYCONFIG_H-$(target) not defined, as there's no header shim needed

else

PYTHON_DIR-$(target)=build/$(os)/Python-$(PYTHON_VERSION)-$(target)
PYTHON_LIB-$(target)=$$(PYTHON_DIR-$(target))/_install/lib/libpython$(PYTHON_VER).a
PYCONFIG_H-$(target)=build/$(os)/python/$$(SDK-$(target))/include/python$(PYTHON_VER)/pyconfig-$$(ARCH-$(target)).h

$$(PYTHON_DIR-$(target))/Makefile: \
		Python-macOS \
		$$(BZIP2_XCFRAMEWORK-$(os)) \
		$$(XZ_XCFRAMEWORK-$(os)) \
		$$(OPENSSL_XCFRAMEWORK-$(os)) \
		$$(LIBFFI_XCFRAMEWORK-$(os)) \
		$$(PYTHON_XCFRAMEWORK-macOS) \
		downloads/Python-$(PYTHON_VERSION).tgz
	@echo ">>> Unpack and configure Python for $(target)"
	mkdir -p $$(PYTHON_DIR-$(target))
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$(target))
	# Apply target Python patches
	cd $$(PYTHON_DIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Generate the embedded module configuration
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded \
		$(PROJECT_DIR)/patch/Python/Setup.$(os) \
		$(PROJECT_DIR)/patch/Python/Setup.$(target) | \
			sed -e "s/{{slice}}/$$(SLICE-$$(SDK-$(target)))/g" \
			> $$(PYTHON_DIR-$(target))/Modules/Setup.local
	# Configure target Python
	cd $$(PYTHON_DIR-$(target)) && \
		./configure \
			CC="$$(CC-$(target))" LD="$$(CC-$(target))" \
			--host=$$(MACHINE_DETAILED-$(target))-apple-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') \
			--build=$(HOST_ARCH)-apple-darwin \
			--with-build-python=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/_install/bin/python$(PYTHON_VER) \
			--prefix="$(PROJECT_DIR)/$$(PYTHON_DIR-$(target))/_install" \
			--without-doc-strings --enable-ipv6 --without-ensurepip \
			--with-openssl=../openssl/$$(SDK-$(target)) \
			ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
			$$(PYTHON_CONFIGURE-$(os)) \
			2>&1 | tee -a ../python-$(target).config.log

$$(PYTHON_DIR-$(target))/python.exe: $$(PYTHON_DIR-$(target))/Makefile
	@echo ">>> Build Python for $(target)"
	cd $$(PYTHON_DIR-$(target)) && \
		make all \
		2>&1 | tee -a ../python-$(target).build.log

$$(PYTHON_LIB-$(target)): $$(PYTHON_DIR-$(target))/python.exe
	@echo ">>> Install Python for $(target)"
	cd $$(PYTHON_DIR-$(target)) && \
		make install \
		2>&1 | tee -a ../python-$(target).install.log

$$(PYCONFIG_H-$(target)): $$(PYTHON_LIB-$(target))
	@echo ">>> Install pyconfig headers for $(target)"
	cp $(PROJECT_DIR)/patch/Python/pyconfig-$(os).h build/$(os)/python/$$(SDK-$(target))/include/python$(PYTHON_VER)/pyconfig.h
	cp $$(PYTHON_DIR-$(target))/_install/include/python$(PYTHON_VER)/pyconfig.h $$(PYCONFIG_H-$(target))

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
	@echo "BZIP2_DIR-$(target): $$(BZIP2_DIR-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "XZ_DIR-$(target): $$(XZ_DIR-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "OPENSSL_DIR-$(target): $$(OPENSSL_DIR-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "OPENSSL_CRYPTO_LIB-$(target): $$(OPENSSL_CRYPTO_LIB-$(target))"
	@echo "LIBFFI_DIR-$(target): $$(LIBFFI_DIR-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
	@echo "PYTHON_DIR-$(target): $$(PYTHON_DIR-$(target))"
	@echo "PYTHON_LIB-$(target): $$(PYTHON_LIB-$(target))"
	@echo "PYCONFIG_H-$(target): $$(PYCONFIG_H-$(target))"
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

SDK_TARGETS-$(sdk)=$$(filter $(sdk).%,$$(TARGETS-$(os)))
SDK_ARCHES-$(sdk)=$$(sort $$(subst .,,$$(suffix $$(SDK_TARGETS-$(sdk)))))

###########################################################################
# SDK: BZip2
###########################################################################

BZIP2_FATLIB-$(sdk)=build/$(os)/bzip2/$(sdk)/lib/libbzip2.a

$$(BZIP2_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(BZIP2_LIB-$$(target)))
	@echo ">>> Build BZip2 fat library for $(sdk)"
	mkdir -p build/$(os)/bzip2/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -no_warning_for_no_symbols -static -o $$@ $$^ \
		2>&1 | tee -a build/$(os)/bzip2-$(sdk).libtool.log
	# Copy headers from the first target associated with the SDK
	cp -r $$(BZIP2_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/bzip2/$(sdk)

###########################################################################
# SDK: XZ (LZMA)
###########################################################################

XZ_FATLIB-$(sdk)=build/$(os)/xz/$(sdk)/lib/libxz.a

$$(XZ_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(XZ_LIB-$$(target)))
	@echo ">>> Build XZ fat library for $(sdk)"
	mkdir -p build/$(os)/xz/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -no_warning_for_no_symbols -static -o $$@ $$^ \
		2>&1 | tee -a build/$(os)/xz-$(sdk).libtool.log
	# Copy headers from the first target associated with the SDK
	cp -r $$(XZ_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/xz/$(sdk)

###########################################################################
# SDK: OpenSSL
###########################################################################

OPENSSL_FATLIB-$(sdk)=build/$(os)/openssl/$(sdk)/lib/libOpenSSL.a

$$(OPENSSL_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)))
	@echo ">>> Build OpenSSL fat library for $(sdk)"
	mkdir -p build/$(os)/openssl/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -no_warning_for_no_symbols -static -o $$@ \
		$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)) $$(OPENSSL_CRYPTO_LIB-$$(target))) \
		2>&1 | tee -a build/$(os)/openssl-$(sdk).libtool.log
	# Copy headers from the first target associated with the SDK
	cp -r $$(OPENSSL_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/openssl/$(sdk)

###########################################################################
# SDK: libFFI
###########################################################################

LIBFFI_FATLIB-$(sdk)=$$(LIBFFI_DIR-$(os))/_install/$(sdk)/libFFI.a

$$(LIBFFI_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(LIBFFI_LIB-$$(target)))
	@echo ">>> Build libFFI fat library for $(sdk)"
	mkdir -p $$(LIBFFI_DIR-$(os))/_install/$(sdk)
	xcrun --sdk $(sdk) libtool -no_warning_for_no_symbols -static -o $$@ $$^ \
		2>&1 | tee -a build/$(os)/libffi-$(sdk).libtool.log
	# Copy headers from the first target associated with the SDK
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_common/include \
		$$(LIBFFI_DIR-$(os))/_install/$(sdk)
	cp -f -r $$(LIBFFI_DIR-$(os))/darwin_$(shell echo $(os) | tr '[:upper:]' '[:lower:]')/include/* \
		$$(LIBFFI_DIR-$(os))/_install/$(sdk)/include

###########################################################################
# SDK: Python
###########################################################################

PYTHON_DIR-$(sdk)=build/$(os)/python/$(sdk)
PYTHON_FATLIB-$(sdk)=$$(PYTHON_DIR-$(sdk))/lib/libPython.a

ifeq ($(os),macOS)
# There's a single OS-level build for macOS; the fat library is a direct copy of
# OS build, and the headers are the unmodifed headers produced by the OS build.

$$(PYTHON_FATLIB-$(sdk)): $$(PYTHON_LIB-$$(firstword $$(SDK_TARGETS-$(sdk))))
	@echo ">>> Build Python fat library for $(sdk)"
	# Copy the OS-level library
	mkdir -p build/$(os)/python/$(sdk)/lib
	cp $$(PYTHON_LIB-$$(firstword $$(SDK_TARGETS-$(sdk)))) $$(PYTHON_FATLIB-$(sdk))
	# Copy headers from the OS-level build
	cp -r $$(PYTHON_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/python/$(sdk)

else

$$(PYTHON_FATLIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_LIB-$$(target)))
	@echo ">>> Build Python fat library for $(sdk)"
	mkdir -p build/$(os)/python/$(sdk)/lib
	xcrun --sdk $(sdk) libtool -no_warning_for_no_symbols -static -o $$@ $$^ \
		2>&1 | tee -a build/$(os)/python-$(sdk).libtool.log
	# Copy headers from the first target associated with the SDK
	cp -r $$(PYTHON_DIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/_install/include build/$(os)/python/$(sdk)

endif

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
	@echo "PYTHON_DIR-$(sdk): $$(PYTHON_DIR-$(sdk))"
	@echo "PYTHON_FATLIB-$(sdk): $$(PYTHON_FATLIB-$(sdk))"
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

# Expand the build-target macro for target on this OS
$$(foreach target,$$(TARGETS-$(os)),$$(eval $$(call build-target,$$(target),$(os))))

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: BZip2
###########################################################################

BZIP2_XCFRAMEWORK-$(os)=build/$(os)/Support/BZip2.xcframework

$$(BZIP2_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(BZIP2_FATLIB-$$(sdk)))
	@echo ">>> Create BZip2.XCFramework on $(os)"
	mkdir -p $$(BZIP2_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(BZIP2_FATLIB-$$(sdk)) -headers build/$(os)/bzip2/$$(sdk)/include) \
		2>&1 | tee -a build/$(os)/bzip2-$(os).xcframework.log

BZip2-$(os): $$(BZIP2_XCFRAMEWORK-$(os))

clean-BZip2-$(os):
	@echo ">>> Clean BZip2 build products on $(os)"
	rm -rf build/$(os)/bzip2-$(BZIP2_VERSION)-* \
		build/$(os)/bzip2 \
		build/$(os)/bzip2-*.log \
		build/$(os)/Support/BZip2.xcframework

###########################################################################
# Build: XZ (LZMA)
###########################################################################

XZ_XCFRAMEWORK-$(os)=build/$(os)/Support/XZ.xcframework

$$(XZ_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(XZ_FATLIB-$$(sdk)))
	@echo ">>> Create XZ.XCFramework on $(os)"
	mkdir -p $$(XZ_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(XZ_FATLIB-$$(sdk)) -headers build/$(os)/xz/$$(sdk)/include) \
		2>&1 | tee -a build/$(os)/xz-$(os).xcframework.log

XZ-$(os): $$(XZ_XCFRAMEWORK-$(os))

clean-XZ-$(os):
	@echo ">>> Clean XZ build products on $(os)"
	rm -rf build/$(os)/xz-$(XZ_VERSION)-* \
		build/$(os)/xz \
		build/$(os)/xz-*.log \
		build/$(os)/Support/XZ.xcframework

###########################################################################
# Build: OpenSSL
###########################################################################

OPENSSL_XCFRAMEWORK-$(os)=build/$(os)/Support/OpenSSL.xcframework

$$(OPENSSL_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(OPENSSL_FATLIB-$$(sdk)))
	@echo ">>> Create OpenSSL.XCFramework on $(os)"
	mkdir -p $$(OPENSSL_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(OPENSSL_FATLIB-$$(sdk)) -headers build/$(os)/openssl/$$(sdk)/include) \
		2>&1 | tee -a build/$(os)/openssl-$(os).xcframework.log

OpenSSL-$(os): $$(OPENSSL_XCFRAMEWORK-$(os))

clean-OpenSSL-$(os):
	@echo ">>> Clean OpenSSL build products on $(os)"
	rm -rf build/$(os)/openssl-$(OPENSSL_VERSION)-* \
		build/$(os)/openssl \
		build/$(os)/openssl-*.log \
		build/$(os)/Support/OpenSSL.xcframework

###########################################################################
# Build: libFFI
###########################################################################

# macOS uses the system-provided libFFI, so there's no need to package
# a libFFI framework for macOS.
ifneq ($(os),macOS)

LIBFFI_XCFRAMEWORK-$(os)=build/$(os)/Support/libFFI.xcframework
LIBFFI_DIR-$(os)=build/$(os)/libffi-$(LIBFFI_VERSION)

$$(LIBFFI_DIR-$(os))/darwin_common/include/ffi.h: downloads/libffi-$(LIBFFI_VERSION).tgz $$(PYTHON_XCFRAMEWORK-macOS)
	@echo ">>> Unpack and configure libFFI sources on $(os)"
	mkdir -p $$(LIBFFI_DIR-$(os))
	tar zxf downloads/libffi-$(LIBFFI_VERSION).tgz --strip-components 1 -C $$(LIBFFI_DIR-$(os))
	# Patch the build to add support for new platforms
	cd $$(LIBFFI_DIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/libffi.patch
	# Configure the build
	cd $$(LIBFFI_DIR-$(os)) && \
		PATH="$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/_install/bin:$(PATH)" \
		python$(PYTHON_VER) generate-darwin-source-and-headers.py --only-$(shell echo $(os) | tr '[:upper:]' '[:lower:]') \
		2>&1 | tee -a ../libffi-$(os).config.log

$$(LIBFFI_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(LIBFFI_FATLIB-$$(sdk)))
	@echo ">>> Create libFFI.XCFramework on $(os)"
	mkdir -p $$(LIBFFI_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(LIBFFI_FATLIB-$$(sdk)) -headers $$(LIBFFI_DIR-$(os))/_install/$$(sdk)/include) \
		2>&1 | tee -a build/$(os)/libffi-$(os).xcframework.log

endif

libFFI-$(os): $$(LIBFFI_XCFRAMEWORK-$(os))

clean-libFFI-$(os):
	@echo ">>> Clean libFFI build products on $(os)"
	rm -rf build/$(os)/libffi-$(LIBFFI_VERSION) \
		build/$(os)/libffi-*.log \
		build/$(os)/Support/libFFI.xcframework


###########################################################################
# Build: Python
###########################################################################

PYTHON_XCFRAMEWORK-$(os)=build/$(os)/Support/Python.xcframework
PYTHON_RESOURCES-$(os)=build/$(os)/Support/Python/Resources/lib

# macOS builds a single Python universal2 target; thus it needs to be
# configured in the `build` macro, not the `build-target` macro.
ifeq ($(os),macOS)

# On macOS, there's a single target and a single output dir,
# rather than a target for each architecture.
PYTHON_TARGETS-$(os)=macOS

# For convenience on macOS, define an OS-level PYTHON_DIR and PYTHON_LIB.
# They are proxies of the values set for the first target, since all target
# constants should have the same value for macOS builds
PYTHON_DIR-$(os)=$$(PYTHON_DIR-$$(firstword $$(TARGETS-$(os))))
PYTHON_LIB-$(os)=$$(PYTHON_LIB-$$(firstword $$(TARGETS-$(os))))

$$(PYTHON_DIR-$(os))/Makefile: \
		$$(BZIP2_XCFRAMEWORK-$(os)) \
		$$(XZ_XCFRAMEWORK-$(os)) \
		$$(OPENSSL_XCFRAMEWORK-$(os)) \
		downloads/Python-$(PYTHON_VERSION).tgz
	@echo ">>> Unpack and configure Python for $(os)"
	mkdir -p $$(PYTHON_DIR-$(os))
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$(os))
	# Apply target Python patches
	cd $$(PYTHON_DIR-$(os)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	cat $(PROJECT_DIR)/patch/Python/Setup.embedded \
		$(PROJECT_DIR)/patch/Python/Setup.$(os) | \
			sed -e "s/{{slice}}/$$(SLICE-macosx)/g" \
			> $$(PYTHON_DIR-$(os))/Modules/Setup.local
	# Configure target Python
	cd $$(PYTHON_DIR-$(os)) && \
		./configure \
			CC="$(CC-macosx)" LD="$(CC-macosx)" \
			--prefix="$(PROJECT_DIR)/$$(PYTHON_DIR-$(os))/_install" \
			--without-doc-strings --enable-ipv6 --without-ensurepip --enable-universalsdk --with-universal-archs=universal2 \
			--with-openssl=../openssl/macosx \
			$$(PYTHON_CONFIGURE-$(os)) \
			2>&1 | tee -a ../python-$(os).config.log

$$(PYTHON_DIR-$(os))/python.exe: \
		$$(PYTHON_DIR-$(os))/Makefile
	@echo ">>> Build Python for $(os)"
	cd $$(PYTHON_DIR-$(os)) && \
		PATH="$(PROJECT_DIR)/$(PYTHON_DIR-$(os))/_install/bin:$(PATH)" \
		make all \
		2>&1 | tee -a ../python-$(os).build.log

$$(PYTHON_LIB-$(os)): $$(PYTHON_DIR-$(os))/python.exe
	@echo ">>> Install Python for $(os)"
	cd $$(PYTHON_DIR-$(os)) && \
		PATH="$(PROJECT_DIR)/$(PYTHON_DIR-$(os))/_install/bin:$(PATH)" \
		make install \
		2>&1 | tee -a ../python-$(os).install.log

else

# The targets for Python on OSes other than macOS
# are the same as they are for every other library
PYTHON_TARGETS-$(os)=$$(TARGETS-$(os))

endif

$$(PYTHON_XCFRAMEWORK-$(os)): $$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_FATLIB-$$(sdk))) $$(foreach target,$$(PYTHON_TARGETS-$(os)),$$(PYCONFIG_H-$$(target)))
	@echo ">>> Create Python.XCFramework on $(os)"
	mkdir -p $$(PYTHON_XCFRAMEWORK-$(os))
	xcodebuild -create-xcframework \
		-output $$@ $$(foreach sdk,$$(SDKS-$(os)),-library $$(PYTHON_FATLIB-$$(sdk)) -headers $$(PYTHON_DIR-$$(sdk))/include/python$(PYTHON_VER)) \
		2>&1 | tee -a build/$(os)/python-$(os).xcframework.log
 	# Copy the standard library from the first target listed
	mkdir -p $$(PYTHON_RESOURCES-$(os))
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(PYTHON_TARGETS-$(os))))/_install/lib/python$(PYTHON_VER) \
		$$(PYTHON_RESOURCES-$(os))

Python-$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

clean-Python-$(os):
	@echo ">>> Clean Python build products on $(os)"
	rm -rf \
		dist/Python-$(PYTHON_VER)-$(os) \
		build/$(os)/Python-$(PYTHON_VERSION)-* \
		build/$(os)/python \
		build/$(os)/python-*.log \
		build/$(os)/Support/Python.xcframework \
		build/$(os)/Support/Python

dev-clean-Python-$(os):
	@echo ">>> Partially clean Python build products on $(os) so that local code modifications can be made"
	rm -rf \
		dist/Python-$(PYTHON_VER)-$(os)-* \
		build/$(os)/Python-$(PYTHON_VERSION)-*/python.exe \
		build/$(os)/Python-$(PYTHON_VERSION)-*/_install \
		build/$(os)/python \
		build/$(os)/python-*.log \
		build/$(os)/Support/Python.xcframework \
		build/$(os)/Support/Python

###########################################################################
# Build
###########################################################################

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: \
		$$(BZIP2_XCFRAMEWORK-$(os)) \
		$$(XZ_XCFRAMEWORK-$(os)) \
		$$(OPENSSL_XCFRAMEWORK-$(os)) \
		$$(LIBFFI_XCFRAMEWORK-$(os)) \
		$$(PYTHON_XCFRAMEWORK-$(os))
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
	rm -rf \
		build/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz \
		dist/Python-$(PYTHON_VER)-$(os)-support.test-$(BUILD_NUMBER).tar.gz \

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo "BZIP2_XCFRAMEWORK-$(os): $$(BZIP2_XCFRAMEWORK-$(os))"
	@echo "XZ_XCFRAMEWORK-$(os): $$(XZ_XCFRAMEWORK-$(os))"
	@echo "OPENSSL_XCFRAMEWORK-$(os): $$(OPENSSL_XCFRAMEWORK-$(os))"
	@echo "LIBFFI_XCFRAMEWORK-$(os): $$(LIBFFI_XCFRAMEWORK-$(os))"
	@echo "LIBFFI_DIR-$(os): $$(LIBFFI_DIR-$(os))"
	@echo "PYTHON_XCFRAMEWORK-$(os): $$(PYTHON_XCFRAMEWORK-$(os))"
	@echo "PYTHON_RESOURCES-$(os): $$(PYTHON_RESOURCES-$(os))"
	@echo "PYTHON_TARGETS-$(os): $$(PYTHON_TARGETS-$(os))"
	@echo "PYTHON_DIR-$(os): $$(PYTHON_DIR-$(os))"
	@echo "PYTHON_LIB-$(os): $$(PYTHON_LIB-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand cross-platform build and clean targets for each output product
XZ: $(foreach os,$(OS_LIST),XZ-$(os))
clean-XZ: $(foreach os,$(OS_LIST),clean-XZ-$(os))

BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
clean-BZip2: $(foreach os,$(OS_LIST),clean-BZip2-$(os))

OpenSSL: $(foreach os,$(OS_LIST),OpenSSL-$(os))
clean-OpenSSL: $(foreach os,$(OS_LIST),clean-OpenSSL-$(os))

libFFI: $(foreach os,$(OS_LIST),libFFI-$(os))
clean-libFFI: $(foreach os,$(OS_LIST),clean-libFFI-$(os))

Python: $(foreach os,$(OS_LIST),Python-$(os))
clean-Python: $(foreach os,$(OS_LIST),clean-Python-$(os))
dev-clean-Python: $(foreach os,$(OS_LIST),dev-clean-Python-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))