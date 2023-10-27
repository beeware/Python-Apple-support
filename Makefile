#
# Useful targets:
# - all             - build everything
# - macOS           - build everything for macOS
# - iOS             - build everything for iOS
# - tvOS            - build everything for tvOS
# - watchOS         - build everything for watchOS

# Current directory
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=custom

# Version of packages that will be compiled by this meta-package
# PYTHON_VERSION is the full version number (e.g., 3.10.0b3)
# PYTHON_MICRO_VERSION is the full version number, without any alpha/beta/rc suffix. (e.g., 3.10.0)
# PYTHON_VER is the major/minor version (e.g., 3.10)
PYTHON_VERSION=3.9.18
PYTHON_MICRO_VERSION=$(shell echo $(PYTHON_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_VER=$(basename $(PYTHON_VERSION))

# The binary releases of dependencies, published at:
# macOS:
#     https://github.com/beeware/cpython-macOS-source-deps/releases
# iOS, tvOS, watchOS:
#     https://github.com/beeware/cpython-apple-source-deps/releases
BZIP2_VERSION=1.0.8-1
XZ_VERSION=5.4.4-1
OPENSSL_VERSION=3.0.12-1
LIBFFI_VERSION=3.4.4-1

# Supported OS
OS_LIST=macOS iOS tvOS watchOS

CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
VERSION_MIN-macOS=11.0
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
HOST_PYTHON=$(shell which python$(PYTHON_VER))

# Force the path to be minimal. This ensures that anything in the user environment
# (in particular, homebrew and user-provided Python installs) aren't inadvertently
# linked into the support package.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

# Build for all operating systems
all: $(OS_LIST)

.PHONY: \
	all clean distclean update-patch vars \
	$(foreach os,$(OS_LIST),$(os) clean-$(os) dev-clean-$(os) vars-$(os)) \
	$(foreach os,$(OS_LIST),$(foreach sdk,$$(sort $$(basename $$(TARGETS-$(os)))),$(sdk) vars-$(sdk)))
	$(foreach os,$(OS_LIST),$(foreach target,$$(TARGETS-$(os)),$(target) vars-$(target)))

# Clean all builds
clean:
	rm -rf build dist install support

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

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
# Setup: Python
###########################################################################

downloads/Python-$(PYTHON_VERSION).tar.gz:
	@echo ">>> Download Python sources"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $@ \
		https://www.python.org/ftp/python/$(PYTHON_MICRO_VERSION)/Python-$(PYTHON_VERSION).tgz

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

# $(target) can be broken up into is composed of $(SDK).$(ARCH)
SDK-$(target)=$$(basename $(target))
ARCH-$(target)=$$(subst .,,$$(suffix $(target)))

WHEEL_TAG-$(target)=py3-none-$$(shell echo $$(OS_LOWER-$(target))_$$(VERSION_MIN-$(os))_$(target) | sed "s/\./_/g")

ifeq ($(os),macOS)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-darwin
else
	ifeq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))
	else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))-simulator
	endif
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CFLAGS-$(target)=\
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))
LDFLAGS-$(target)=\
	-isysroot $$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))

###########################################################################
# Target: Aliases
###########################################################################

support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(target))-clang:
	patch/make-xcrun-alias $$@ "--sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))"

support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(target))-cpp:
	patch/make-xcrun-alias $$@ "--sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target)) -E"

###########################################################################
# Target: BZip2
###########################################################################

BZIP2_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(target)=$$(BZIP2_INSTALL-$(target))/lib/libbz2.a

downloads/bzip2-$(BZIP2_VERSION)-$(target).tar.gz:
	@echo ">>> Download BZip2 for $(target)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-apple-source-deps/releases/download/BZip2-$(BZIP2_VERSION)/bzip2-$(BZIP2_VERSION)-$(target).tar.gz

$$(BZIP2_LIB-$(target)): downloads/bzip2-$(BZIP2_VERSION)-$(target).tar.gz
	@echo ">>> Install BZip2 for $(target)"
	mkdir -p $$(BZIP2_INSTALL-$(target))
	cd $$(BZIP2_INSTALL-$(target)) && tar zxvf $(PROJECT_DIR)/downloads/bzip2-$(BZIP2_VERSION)-$(target).tar.gz
	# Ensure the target is marked as clean.
	touch $$(BZIP2_LIB-$(target))

###########################################################################
# Target: XZ (LZMA)
###########################################################################

XZ_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_LIB-$(target)=$$(XZ_INSTALL-$(target))/lib/liblzma.a

downloads/xz-$(XZ_VERSION)-$(target).tar.gz:
	@echo ">>> Download XZ for $(target)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-apple-source-deps/releases/download/XZ-$(XZ_VERSION)/xz-$(XZ_VERSION)-$(target).tar.gz

$$(XZ_LIB-$(target)): downloads/xz-$(XZ_VERSION)-$(target).tar.gz
	@echo ">>> Install XZ for $(target)"
	mkdir -p $$(XZ_INSTALL-$(target))
	cd $$(XZ_INSTALL-$(target)) && tar zxvf $(PROJECT_DIR)/downloads/xz-$(XZ_VERSION)-$(target).tar.gz
	# Ensure the target is marked as clean.
	touch $$(XZ_LIB-$(target))

###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libssl.a

downloads/openssl-$(OPENSSL_VERSION)-$(target).tar.gz:
	@echo ">>> Download OpenSSL for $(target)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-apple-source-deps/releases/download/OpenSSL-$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION)-$(target).tar.gz

$$(OPENSSL_SSL_LIB-$(target)): downloads/openssl-$(OPENSSL_VERSION)-$(target).tar.gz
	@echo ">>> Install OpenSSL for $(target)"
	mkdir -p $$(OPENSSL_INSTALL-$(target))
	cd $$(OPENSSL_INSTALL-$(target)) && tar zxvf $(PROJECT_DIR)/downloads/openssl-$(OPENSSL_VERSION)-$(target).tar.gz
	# Ensure the target is marked as clean.
	touch $$(OPENSSL_SSL_LIB-$(target))

###########################################################################
# Target: libFFI
###########################################################################

# macOS builds use the system libFFI, so there's no need to do
# a per-target build on macOS.
# The configure step is performed as part of the OS-level build.
ifneq ($(os),macOS)

LIBFFI_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/libffi-$(LIBFFI_VERSION)
LIBFFI_LIB-$(target)=$$(LIBFFI_INSTALL-$(target))/lib/libffi.a

downloads/libffi-$(LIBFFI_VERSION)-$(target).tar.gz:
	@echo ">>> Download libFFI for $(target)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-apple-source-deps/releases/download/libFFI-$(LIBFFI_VERSION)/libffi-$(LIBFFI_VERSION)-$(target).tar.gz

$$(LIBFFI_LIB-$(target)): downloads/libffi-$(LIBFFI_VERSION)-$(target).tar.gz
	@echo ">>> Install libFFI for $(target)"
	mkdir -p $$(LIBFFI_INSTALL-$(target))
	cd $$(LIBFFI_INSTALL-$(target)) && tar zxvf $(PROJECT_DIR)/downloads/libffi-$(LIBFFI_VERSION)-$(target).tar.gz
	# Ensure the target is marked as clean.
	touch $$(LIBFFI_LIB-$(target))

endif

###########################################################################
# Target: Python
###########################################################################

# macOS builds are compiled as a single universal2 build.
# The macOS Python build is configured in the `build-sdk` macro, rather than the
# `build-target` macro. However, the site-customize scripts generated here, per target.
ifneq ($(os),macOS)

PYTHON_SRCDIR-$(target)=build/$(os)/$(target)/python-$(PYTHON_VERSION)
PYTHON_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/python-$(PYTHON_VERSION)
PYTHON_LIB-$(target)=$$(PYTHON_INSTALL-$(target))/lib/libpython$(PYTHON_VER).a

$$(PYTHON_SRCDIR-$(target))/configure: \
		downloads/Python-$(PYTHON_VERSION).tar.gz \
		$$(BZIP2_LIB-$(target)) \
		$$(XZ_LIB-$(target)) \
		$$(OPENSSL_SSL_LIB-$(target)) \
		$$(LIBFFI_LIB-$(target)) \
		$$(PYTHON_LIB-macosx)
	@echo ">>> Unpack and configure Python for $(target)"
	mkdir -p $$(PYTHON_SRCDIR-$(target))
	tar zxf downloads/Python-$(PYTHON_VERSION).tar.gz --strip-components 1 -C $$(PYTHON_SRCDIR-$(target))
	# Apply target Python patches
	cd $$(PYTHON_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(PYTHON_SRCDIR-$(target))/configure

$$(PYTHON_SRCDIR-$(target))/Makefile: \
		support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$$(SDK-$(target)))-ar \
		support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(target))-clang \
		support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(target))-cpp \
		$$(PYTHON_SRCDIR-$(target))/configure
	# Configure target Python
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/bin:$(PATH)" \
		./configure \
			AR=$$(TARGET_TRIPLE-$$(SDK-$(target)))-ar \
			CC=$$(TARGET_TRIPLE-$(target))-clang \
			CPP=$$(TARGET_TRIPLE-$(target))-cpp \
			CXX=$$(TARGET_TRIPLE-$(target))-clang \
			CFLAGS="$$(CFLAGS-$(target)) -I$$(BZIP2_INSTALL-$(target))/include -I$$(XZ_INSTALL-$(target))/include" \
			LDFLAGS="$$(LDFLAGS-$(target)) -L$$(BZIP2_INSTALL-$(target))/lib -L$$(XZ_INSTALL-$(target))/lib" \
			LIBFFI_INCLUDEDIR="$$(LIBFFI_INSTALL-$(target))/include" \
			LIBFFI_LIBDIR="$$(LIBFFI_INSTALL-$(target))/lib" \
			LIBFFI_LIB="ffi" \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(PYTHON_INSTALL-$(target))" \
			--enable-ipv6 \
			--with-openssl="$$(OPENSSL_INSTALL-$(target))" \
			--without-ensurepip \
			ac_cv_file__dev_ptmx=no \
			ac_cv_file__dev_ptc=no \
			$$(PYTHON_CONFIGURE-$(os)) \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).config.log

$$(PYTHON_SRCDIR-$(target))/python.exe: $$(PYTHON_SRCDIR-$(target))/Makefile
	@echo ">>> Build Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/bin:$(PATH)" \
			make all \
				2>&1 | tee -a ../python-$(PYTHON_VERSION).build.log

$$(PYTHON_LIB-$(target)): $$(PYTHON_SRCDIR-$(target))/python.exe
	@echo ">>> Install Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$$(PYTHON_INSTALL-macosx)/bin:$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/bin:$(PATH)" \
			make install \
				2>&1 | tee -a ../python-$(PYTHON_VERSION).install.log

endif

PYTHON_SITECUSTOMIZE-$(target)=$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/platform-site/$(target)/sitecustomize.py

$$(PYTHON_SITECUSTOMIZE-$(target)):
	@echo ">>> Create cross-platform sitecustomize.py for $(target)"
	mkdir -p $$(dir $$(PYTHON_SITECUSTOMIZE-$(target)))
	cat $(PROJECT_DIR)/patch/Python/sitecustomize.$(os).py \
		| sed -e "s/{{os}}/$(os)/g" \
		| sed -e "s/{{arch}}/$$(ARCH-$(target))/g" \
		| sed -e "s/{{tag}}/$$(OS_LOWER-$(target))-$$(VERSION_MIN-$(os))-$$(SDK-$(target))-$$(ARCH-$(target))/g" \
		> $$(PYTHON_SITECUSTOMIZE-$(target))

$(target): $$(PYTHON_SITECUSTOMIZE-$(target)) $$(PYTHON_LIB-$(target))

###########################################################################
# Target: Debug
###########################################################################

vars-$(target):
	@echo ">>> Environment variables for $(target)"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "TARGET_TRIPLE-$(target): $$(TARGET_TRIPLE-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CFLAGS-$(target): $$(CFLAGS-$(target))"
	@echo "LDFLAGS-$(target): $$(LDFLAGS-$(target))"
	@echo "BZIP2_INSTALL-$(target): $$(BZIP2_INSTALL-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "XZ_INSTALL-$(target): $$(XZ_INSTALL-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "OPENSSL_INSTALL-$(target): $$(OPENSSL_INSTALL-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "LIBFFI_INSTALL-$(target): $$(LIBFFI_INSTALL-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
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

CFLAGS-$(sdk)=$$(CFLAGS-$(os))
LDFLAGS-$(sdk)=$$(CFLAGS-$(os))

# Predeclare SDK constants that are used by the build-target macro
PYTHON_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_LIB-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/lib/libpython$(PYTHON_VER).a
PYTHON_INCLUDE-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/include/python$(PYTHON_VER)
PYTHON_STDLIB-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/lib/python$(PYTHON_VER)

ifeq ($(os),macOS)
TARGET_TRIPLE-$(sdk)=apple-darwin
else
	ifeq ($$(findstring simulator,$(sdk)),)
TARGET_TRIPLE-$(sdk)=apple-$$(OS_LOWER-$(sdk))$$(VERSION_MIN-$(os))
	else
TARGET_TRIPLE-$(sdk)=apple-$$(OS_LOWER-$(sdk))$$(VERSION_MIN-$(os))-simulator
	endif
endif

# Expand the build-target macro for target on this OS
$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(eval $$(call build-target,$$(target),$(os))))

###########################################################################
# SDK: Aliases
###########################################################################

support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(sdk))-clang:
	patch/make-xcrun-alias $$@ "--sdk $(sdk) clang"

support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(sdk))-cpp:
	patch/make-xcrun-alias $$@ "--sdk $(sdk) clang -E"

support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(sdk))-ar:
	patch/make-xcrun-alias $$@ "--sdk $(sdk) ar"

###########################################################################
# SDK: BZip2
###########################################################################

BZIP2_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(sdk)=$$(BZIP2_INSTALL-$(sdk))/lib/libbz2.a

# This is only used on macOS.
downloads/bzip2-$(BZIP2_VERSION)-$(sdk).tar.gz:
	@echo ">>> Download BZip2 for $(sdk)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-macOS-source-deps/releases/download/BZip2-$(BZIP2_VERSION)/bzip2-$(BZIP2_VERSION)-$(sdk).tar.gz

$$(BZIP2_LIB-$(sdk)): downloads/bzip2-$(BZIP2_VERSION)-$(sdk).tar.gz
	@echo ">>> Install BZip2 for $(sdk)"
	mkdir -p $$(BZIP2_INSTALL-$(sdk))
	cd $$(BZIP2_INSTALL-$(sdk)) && tar zxvf $(PROJECT_DIR)/downloads/bzip2-$(BZIP2_VERSION)-$(sdk).tar.gz
	# Ensure the target is marked as clean.
	touch $$(BZIP2_LIB-$(sdk))

###########################################################################
# SDK: XZ (LZMA)
###########################################################################

XZ_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/xz-$(XZ_VERSION)
XZ_LIB-$(sdk)=$$(XZ_INSTALL-$(sdk))/lib/liblzma.a

# This is only used on macOS.
downloads/xz-$(XZ_VERSION)-$(sdk).tar.gz:
	@echo ">>> Download XZ for $(sdk)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-macOS-source-deps/releases/download/XZ-$(XZ_VERSION)/xz-$(XZ_VERSION)-$(sdk).tar.gz

$$(XZ_LIB-$(sdk)): downloads/xz-$(XZ_VERSION)-$(sdk).tar.gz
	@echo ">>> Install XZ for $(sdk)"
	mkdir -p $$(XZ_INSTALL-$(sdk))
	cd $$(XZ_INSTALL-$(sdk)) && tar zxvf $(PROJECT_DIR)/downloads/xz-$(XZ_VERSION)-$(sdk).tar.gz
	# Ensure the target is marked as clean.
	touch $$(XZ_LIB-$(sdk))

###########################################################################
# SDK: OpenSSL
###########################################################################

OPENSSL_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(sdk)=$$(OPENSSL_INSTALL-$(sdk))/lib/libssl.a

# This is only used on macOS.
downloads/openssl-$(OPENSSL_VERSION)-$(sdk).tar.gz:
	@echo ">>> Download OpenSSL for $(sdk)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-macOS-source-deps/releases/download/OpenSSL-$(OPENSSL_VERSION)/openssl-$(OPENSSL_VERSION)-$(sdk).tar.gz

$$(OPENSSL_SSL_LIB-$(sdk)): downloads/openssl-$(OPENSSL_VERSION)-$(sdk).tar.gz
	@echo ">>> Install OpenSSL for $(sdk)"
	mkdir -p $$(OPENSSL_INSTALL-$(sdk))
	cd $$(OPENSSL_INSTALL-$(sdk)) && tar zxvf $(PROJECT_DIR)/downloads/openssl-$(OPENSSL_VERSION)-$(sdk).tar.gz
	# Ensure the target is marked as clean.
	touch $$(OPENSSL_SSL_LIB-$(sdk))

###########################################################################
# SDK: Python
###########################################################################

# macOS builds are compiled as a single universal2 build. The fat library is a
# direct copy of OS build, and the headers and standard library are unmodified
# from the versions produced by the OS build.
ifeq ($(os),macOS)

PYTHON_SRCDIR-$(sdk)=build/$(os)/$(sdk)/python-$(PYTHON_VERSION)

$$(PYTHON_SRCDIR-$(sdk))/configure: \
 		$$(BZIP2_LIB-$$(sdk)) \
 		$$(XZ_LIB-$$(sdk)) \
 		$$(OPENSSL_SSL_LIB-$$(sdk)) \
		downloads/Python-$(PYTHON_VERSION).tar.gz
	@echo ">>> Unpack and configure Python for $(sdk)"
	mkdir -p $$(PYTHON_SRCDIR-$(sdk))
	tar zxf downloads/Python-$(PYTHON_VERSION).tar.gz --strip-components 1 -C $$(PYTHON_SRCDIR-$(sdk))
	# Apply target Python patches
	cd $$(PYTHON_SRCDIR-$(sdk)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(PYTHON_SRCDIR-$(sdk))/configure

$$(PYTHON_SRCDIR-$(sdk))/Makefile: \
		support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(sdk))-clang \
		support/$(PYTHON_VER)/$(os)/bin/$$(TARGET_TRIPLE-$(sdk))-cpp \
		$$(PYTHON_SRCDIR-$(sdk))/configure
	# Configure target Python
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		PATH="$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/bin:$(PATH)" \
		./configure \
			CC=$$(TARGET_TRIPLE-$(sdk))-clang \
			CPP=$$(TARGET_TRIPLE-$(sdk))-cpp \
			CFLAGS="$$(CFLAGS-$(sdk)) -I$$(BZIP2_INSTALL-$(sdk))/include -I$$(XZ_INSTALL-$(sdk))/include" \
			LDFLAGS="$$(LDFLAGS-$(sdk)) -L$$(XZ_INSTALL-$(sdk))/lib -L$$(BZIP2_INSTALL-$(sdk))/lib" \
			MACOSX_DEPLOYMENT_TARGET="$$(VERSION_MIN-$(os))" \
			--prefix="$$(PYTHON_INSTALL-$(sdk))" \
			--enable-ipv6 \
			--enable-universalsdk \
			--with-openssl="$$(OPENSSL_INSTALL-$(sdk))" \
			--with-universal-archs=universal2 \
			--without-ensurepip \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).config.log

$$(PYTHON_SRCDIR-$(sdk))/python.exe: $$(PYTHON_SRCDIR-$(sdk))/Makefile
	@echo ">>> Build Python for $(sdk)"
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		PATH="$(PROJECT_DIR)/support/$(PYTHON_VER)/$(os)/bin:$(PATH)" \
		make all \
		2>&1 | tee -a ../python-$(PYTHON_VERSION).build.log

$$(PYTHON_LIB-$(sdk)) $$(PYTHON_INCLUDE-$$(sdk))/Python.h $$(PYTHON_STDLIB-$(sdk))/LICENSE.TXT: $$(PYTHON_SRCDIR-$(sdk))/python.exe
	@echo ">>> Install Python for $(sdk)"
	cd $$(PYTHON_SRCDIR-$(sdk)) && \
		make install \
		2>&1 | tee -a ../python-$(PYTHON_VERSION).install.log

else

# Non-macOS builds need to be merged on a per-SDK basis. The merge covers:
# * Merging a fat libPython.a
# * Installing an architecture-sensitive pyconfig.h
# * Merging fat versions of the standard library lib-dynload folder

$$(PYTHON_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_LIB-$$(target)))
	@echo ">>> Build Python fat library for the $(sdk) SDK"
	mkdir -p $$(dir $$(PYTHON_LIB-$(sdk)))
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/python-$(PYTHON_VERSION).lipo.log

$$(PYTHON_INCLUDE-$(sdk))/Python.h: $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python fat headers for the $(sdk) SDK"
	# Copy headers as-is from the first target in the $(sdk) SDK
	mkdir -p $$(shell dirname $$(PYTHON_INCLUDE-$(sdk)))
	cp -r $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include/python$(PYTHON_VER) $$(PYTHON_INCLUDE-$(sdk))
	# Copy the cross-target header from the patch folder
	cp $(PROJECT_DIR)/patch/Python/pyconfig-$(os).h $$(PYTHON_INCLUDE-$(sdk))/pyconfig.h
	# Add the individual headers from each target in an arch-specific name
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_INSTALL-$$(target))/include/python$(PYTHON_VER)/pyconfig.h $$(PYTHON_INCLUDE-$(sdk))/pyconfig-$$(ARCH-$$(target)).h; )

$$(PYTHON_STDLIB-$(sdk))/LICENSE.TXT: $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python stdlib for the $(sdk) SDK"
	mkdir -p $$(PYTHON_STDLIB-$(sdk))/lib-dynload
	# Copy stdlib from the first target associated with the $(sdk) SDK
	cp -r $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/lib/python$(PYTHON_VER)/ $$(PYTHON_STDLIB-$(sdk))

	# Delete the single-SDK parts of the standard library
	rm -rf \
		$$(PYTHON_STDLIB-$(sdk))/_sysconfigdata__*.py \
		$$(PYTHON_STDLIB-$(sdk))/config-* \
		$$(PYTHON_STDLIB-$(sdk))/lib-dynload/*

	# Copy the individual _sysconfigdata modules into names that include the architecture
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/_sysconfigdata_* $$(PYTHON_STDLIB-$(sdk))/; )

	# Copy the individual config modules directories into names that include the architecture
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp -r $$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/config-$(PYTHON_VER)-$(sdk)-$$(ARCH-$$(target)) $$(PYTHON_STDLIB-$(sdk))/; )

	# Merge the binary modules from each target in the $(sdk) SDK into a single binary
	$$(foreach module,$$(wildcard $$(PYTHON_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/lib/python$(PYTHON_VER)/lib-dynload/*),lipo -create -output $$(PYTHON_STDLIB-$(sdk))/lib-dynload/$$(notdir $$(module)) $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_INSTALL-$$(target))/lib/python$(PYTHON_VER)/lib-dynload/$$(notdir $$(module))); )

endif

$(sdk): $$(PYTHON_STDLIB-$(sdk))/LICENSE.TXT

###########################################################################
# SDK: Debug
###########################################################################

vars-$(sdk):
	@echo ">>> Environment variables for $(sdk)"
	@echo "SDK_TARGETS-$(sdk): $$(SDK_TARGETS-$(sdk))"
	@echo "SDK_ARCHES-$(sdk): $$(SDK_ARCHES-$(sdk))"
	@echo "SDK_SLICE-$(sdk): $$(SDK_SLICE-$(sdk))"
	@echo "CFLAGS-$(sdk): $$(CFLAGS-$(sdk))"
	@echo "LDFLAGS-$(sdk): $$(LDFLAGS-$(sdk))"
	@echo "PYTHON_SRCDIR-$(sdk): $$(PYTHON_SRCDIR-$(sdk))"
	@echo "PYTHON_INSTALL-$(sdk): $$(PYTHON_INSTALL-$(sdk))"
	@echo "PYTHON_LIB-$(sdk): $$(PYTHON_LIB-$(sdk))"
	@echo "PYTHON_INCLUDE-$(sdk): $$(PYTHON_INCLUDE-$(sdk))"
	@echo "PYTHON_STDLIB-$(sdk): $$(PYTHON_STDLIB-$(sdk))"
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
# Build: Python
###########################################################################

$$(PYTHON_XCFRAMEWORK-$(os))/Info.plist: \
		$$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_LIB-$$(sdk)) $$(PYTHON_INCLUDE-$$(sdk))/Python.h)
	@echo ">>> Create Python.XCFramework on $(os)"
	mkdir -p $$(dir $$(PYTHON_XCFRAMEWORK-$(os)))
	xcodebuild -create-xcframework \
		-output $$(PYTHON_XCFRAMEWORK-$(os)) $$(foreach sdk,$$(SDKS-$(os)),-library $$(PYTHON_LIB-$$(sdk)) -headers $$(PYTHON_INCLUDE-$$(sdk))) \
		2>&1 | tee -a support/$(PYTHON_VER)/python-$(os).xcframework.log

$$(PYTHON_STDLIB-$(os))/VERSIONS: \
		$$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_STDLIB-$$(sdk))/LICENSE.TXT)
	@echo ">>> Create Python stdlib on $(os)"
	# Copy stdlib from first SDK in $(os)
	cp -r $$(PYTHON_STDLIB-$$(firstword $$(SDKS-$(os)))) $$(PYTHON_STDLIB-$(os))

	# Delete the single-SDK stdlib artefacts from $(os)
	rm -rf \
		$$(PYTHON_STDLIB-$(os))/_sysconfigdata__*.py \
		$$(PYTHON_STDLIB-$(os))/config-* \
		$$(PYTHON_STDLIB-$(os))/lib-dynload/*

	# Copy the config-* contents from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp -r $$(PYTHON_STDLIB-$$(sdk))/config-$(PYTHON_VER)-* $$(PYTHON_STDLIB-$(os)); )

	# Copy the _sysconfigdata modules from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp $$(PYTHON_STDLIB-$$(sdk))/_sysconfigdata__*.py $$(PYTHON_STDLIB-$(os)); )

	# Copy the lib-dynload contents from every SDK in $(os) into the support folder.
	$$(foreach sdk,$$(SDKS-$(os)),cp $$(PYTHON_STDLIB-$$(sdk))/lib-dynload/* $$(PYTHON_STDLIB-$(os))/lib-dynload; )

	@echo ">>> Create VERSIONS file for $(os)"
	echo "Python version: $(PYTHON_VERSION) " > support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Min $(os) version: $$(VERSION_MIN-$(os))" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "---------------------" >> support/$(PYTHON_VER)/$(os)/VERSIONS
ifeq ($(os),macOS)
	echo "libFFI: built-in" >> support/$(PYTHON_VER)/$(os)/VERSIONS
else
	echo "libFFI: $(LIBFFI_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
endif
	echo "BZip2: $(BZIP2_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "OpenSSL: $(OPENSSL_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "XZ: $(XZ_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: \
	$$(PYTHON_XCFRAMEWORK-$(os))/Info.plist \
	$$(PYTHON_STDLIB-$(os))/VERSIONS \
	$$(foreach target,$$(TARGETS-$(os)), $$(PYTHON_SITECUSTOMIZE-$$(target)))

	@echo ">>> Create final distribution artefact for $(os)"
	mkdir -p dist
	# Build a "full" tarball with all content for test purposes
	tar zcvf dist/Python-$(PYTHON_VER)-$(os)-support.test-$(BUILD_NUMBER).tar.gz -X patch/Python/test.exclude -C support/$(PYTHON_VER)/$(os) `ls -A support/$(PYTHON_VER)/$(os)/`
	# Build a distributable tarball
	tar zcvf $$@ -X patch/Python/release.common.exclude -X patch/Python/release.$(os).exclude -C support/$(PYTHON_VER)/$(os) `ls -A support/$(PYTHON_VER)/$(os)/`

clean-$(os):
	@echo ">>> Clean Python build products on $(os)"
	rm -rf \
		build/$(os)/*/python-$(PYTHON_VER)* \
		build/$(os)/*/python-$(PYTHON_VER)*.*.log \
		install/$(os)/*/python-$(PYTHON_VER)* \
		install/$(os)/*/python-$(PYTHON_VER)*.*.log \
		support/$(PYTHON_VER)/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-*

dev-clean-$(os):
	@echo ">>> Partially clean Python build products on $(os) so that local code modifications can be made"
	rm -rf \
		build/$(os)/*/Python-$(PYTHON_VERSION)/python.exe \
		build/$(os)/*/python-$(PYTHON_VERSION).*.log \
		install/$(os)/*/python-$(PYTHON_VERSION) \
		install/$(os)/*/python-$(PYTHON_VERSION).*.log \
		support/$(PYTHON_VER)/$(os) \
		dist/Python-$(PYTHON_VER)-$(os)-*

###########################################################################
# Build
###########################################################################

$(os): dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo "LIBPYTHON_XCFRAMEWORK-$(os): $$(LIBPYTHON_XCFRAMEWORK-$(os))"
	@echo "PYTHON_XCFRAMEWORK-$(os): $$(PYTHON_XCFRAMEWORK-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))
	@echo ">>> Environment variables for $(os)"
	@echo "HOST_ARCH: $(HOST_ARCH)"
	@echo "HOST_PYTHON: $(HOST_PYTHON)"
	@echo

# Expand cross-platform build and clean targets for each output product
clean: $(foreach os,$(OS_LIST),clean-$(os))
dev-clean: $(foreach os,$(OS_LIST),dev-clean-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
