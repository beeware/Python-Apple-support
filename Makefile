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
# PYTHON_PKG_VERSION is the version number with binary package releases to use
# for macOS binaries. This will be less than PYTHON_VERSION towards the end
# of a release cycle, as official binaries won't be published.
# PYTHON_MICRO_VERSION is the full version number, without any alpha/beta/rc suffix. (e.g., 3.10.0)
# PYTHON_VER is the major/minor version (e.g., 3.10)
PYTHON_VERSION=3.13.0rc1
PYTHON_PKG_VERSION=$(PYTHON_VERSION)
PYTHON_MICRO_VERSION=$(shell echo $(PYTHON_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_PKG_MICRO_VERSION=$(shell echo $(PYTHON_PKG_VERSION) | grep -Eo "\d+\.\d+\.\d+")
PYTHON_VER=$(basename $(PYTHON_VERSION))

# The binary releases of dependencies, published at:
# https://github.com/beeware/cpython-apple-source-deps/releases
BZIP2_VERSION=1.0.8-1
LIBFFI_VERSION=3.4.6-1
MPDECIMAL_VERSION=4.0.0-1
OPENSSL_VERSION=3.0.14-1
XZ_VERSION=5.4.7-1

# Supported OS
OS_LIST=macOS iOS tvOS watchOS

CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
VERSION_MIN-macOS=11.0

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.arm64 iphoneos.arm64
VERSION_MIN-iOS=13.0

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvsimulator.arm64 appletvos.arm64
VERSION_MIN-tvOS=12.0

# watchOS targets
TARGETS-watchOS=watchsimulator.x86_64 watchsimulator.arm64 watchos.arm64_32
VERSION_MIN-watchOS=4.0

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
	all clean distclean update-patch vars config \
	$(foreach os,$(OS_LIST),$(os) clean-$(os) dev-clean-$(os) vars-$(os)) \
	$(foreach os,$(OS_LIST),$(foreach sdk,$$(sort $$(basename $$(TARGETS-$(os)))),$(sdk) vars-$(sdk)))
	$(foreach os,$(OS_LIST),$(foreach target,$$(TARGETS-$(os)),$(target) vars-$(target)))

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads build dist install support

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
		git diff -D v$(PYTHON_VERSION) $(PYTHON_VER)-patched \
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

downloads/python-$(PYTHON_PKG_VERSION)-macos11.pkg:
	@echo ">>> Download macOS Python package"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $@ \
		https://www.python.org/ftp/python/$(PYTHON_PKG_MICRO_VERSION)/python-$(PYTHON_PKG_VERSION)-macos11.pkg

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

ifneq ($(os),macOS)
	ifeq ($$(findstring simulator,$$(SDK-$(target))),)
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))
	else
TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-$$(OS_LOWER-$(target))$$(VERSION_MIN-$(os))-simulator
	endif
endif

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)

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
# Target: mpdecimal
###########################################################################

MPDECIMAL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/mpdecimal-$(MPDECIMAL_VERSION)
MPDECIMAL_LIB-$(target)=$$(MPDECIMAL_INSTALL-$(target))/lib/libmpdec.a

downloads/mpdecimal-$(MPDECIMAL_VERSION)-$(target).tar.gz:
	@echo ">>> Download mpdecimal for $(target)"
	mkdir -p downloads
	curl $(CURL_FLAGS) -o $$@ \
		https://github.com/beeware/cpython-apple-source-deps/releases/download/mpdecimal-$(MPDECIMAL_VERSION)/mpdecimal-$(MPDECIMAL_VERSION)-$(target).tar.gz

$$(MPDECIMAL_LIB-$(target)): downloads/mpdecimal-$(MPDECIMAL_VERSION)-$(target).tar.gz
	@echo ">>> Install mpdecimal for $(target)"
	mkdir -p $$(MPDECIMAL_INSTALL-$(target))
	cd $$(MPDECIMAL_INSTALL-$(target)) && tar zxvf $(PROJECT_DIR)/downloads/mpdecimal-$(MPDECIMAL_VERSION)-$(target).tar.gz
	# Ensure the target is marked as clean.
	touch $$(MPDECIMAL_LIB-$(target))

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
PYTHON_FRAMEWORK-$(target)=$$(PYTHON_INSTALL-$(target))/Python.framework
PYTHON_LIB-$(target)=$$(PYTHON_FRAMEWORK-$(target))/Python
PYTHON_BIN-$(target)=$$(PYTHON_INSTALL-$(target))/bin
PYTHON_INCLUDE-$(target)=$$(PYTHON_FRAMEWORK-$(target))/Headers
PYTHON_STDLIB-$(target)=$$(PYTHON_INSTALL-$(target))/lib/python$(PYTHON_VER)

$$(PYTHON_SRCDIR-$(target))/configure: \
		downloads/Python-$(PYTHON_VERSION).tar.gz \
		$$(BZIP2_LIB-$(target)) \
		$$(LIBFFI_LIB-$(target)) \
		$$(MPDECIMAL_LIB-$(target)) \
		$$(OPENSSL_SSL_LIB-$(target)) \
		$$(XZ_LIB-$(target))
	@echo ">>> Unpack and configure Python for $(target)"
	mkdir -p $$(PYTHON_SRCDIR-$(target))
	tar zxf downloads/Python-$(PYTHON_VERSION).tar.gz --strip-components 1 -C $$(PYTHON_SRCDIR-$(target))
	# Apply target Python patches
	cd $$(PYTHON_SRCDIR-$(target)) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch
	# Make sure the binary scripts are executable
	chmod 755 $$(PYTHON_SRCDIR-$(target))/$(os)/Resources/bin/*
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(PYTHON_SRCDIR-$(target))/configure

$$(PYTHON_SRCDIR-$(target))/Makefile: \
		$$(PYTHON_SRCDIR-$(target))/configure
	# Configure target Python
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/$$(PYTHON_SRCDIR-$(target))/$(os)/Resources/bin:$(PATH)" \
		./configure \
			LIBLZMA_CFLAGS="-I$$(XZ_INSTALL-$(target))/include" \
			LIBLZMA_LIBS="-L$$(XZ_INSTALL-$(target))/lib -llzma" \
			BZIP2_CFLAGS="-I$$(BZIP2_INSTALL-$(target))/include" \
			BZIP2_LIBS="-L$$(BZIP2_INSTALL-$(target))/lib -lbz2" \
			LIBMPDEC_CFLAGS="-I$$(MPDECIMAL_INSTALL-$(target))/include" \
			LIBMPDEC_LIBS="-L$$(MPDECIMAL_INSTALL-$(target))/lib -lmpdec" \
			LIBFFI_CFLAGS="-I$$(LIBFFI_INSTALL-$(target))/include" \
			LIBFFI_LIBS="-L$$(LIBFFI_INSTALL-$(target))/lib -lffi" \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--with-build-python=$(HOST_PYTHON) \
			--enable-ipv6 \
			--with-openssl="$$(OPENSSL_INSTALL-$(target))" \
			--enable-framework="$$(PYTHON_INSTALL-$(target))" \
			--with-system-libmpdec \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).config.log

$$(PYTHON_SRCDIR-$(target))/python.exe: $$(PYTHON_SRCDIR-$(target))/Makefile
	@echo ">>> Build Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/$$(PYTHON_SRCDIR-$(target))/$(os)/Resources/bin:$(PATH)" \
			make -j8 all \
			2>&1 | tee -a ../python-$(PYTHON_VERSION).build.log

$$(PYTHON_LIB-$(target)): $$(PYTHON_SRCDIR-$(target))/python.exe
	@echo ">>> Install Python for $(target)"
	cd $$(PYTHON_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/$$(PYTHON_SRCDIR-$(target))/$(os)/Resources/bin:$(PATH)" \
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
		| sed -e "s/{{tag}}/$$(OS_LOWER-$(target))-$$(VERSION_MIN-$(os))-$$(ARCH-$(target))-$$(SDK-$(target))/g" \
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
	@echo "BZIP2_INSTALL-$(target): $$(BZIP2_INSTALL-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "LIBFFI_INSTALL-$(target): $$(LIBFFI_INSTALL-$(target))"
	@echo "LIBFFI_LIB-$(target): $$(LIBFFI_LIB-$(target))"
	@echo "MPDECIMAL_INSTALL-$(target): $$(MPDECIMAL_INSTALL-$(target))"
	@echo "MPDECIMAL_LIB-$(target): $$(MPDECIMAL_LIB-$(target))"
	@echo "OPENSSL_INSTALL-$(target): $$(OPENSSL_INSTALL-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "XZ_INSTALL-$(target): $$(XZ_INSTALL-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "PYTHON_SRCDIR-$(target): $$(PYTHON_SRCDIR-$(target))"
	@echo "PYTHON_INSTALL-$(target): $$(PYTHON_INSTALL-$(target))"
	@echo "PYTHON_FRAMEWORK-$(target): $$(PYTHON_FRAMEWORK-$(target))"
	@echo "PYTHON_LIB-$(target): $$(PYTHON_LIB-$(target))"
	@echo "PYTHON_BIN-$(target): $$(PYTHON_BIN-$(target))"
	@echo "PYTHON_INCLUDE-$(target): $$(PYTHON_INCLUDE-$(target))"
	@echo "PYTHON_STDLIB-$(target): $$(PYTHON_STDLIB-$(target))"
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

# Expand the build-target macro for target on this OS
$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(eval $$(call build-target,$$(target),$(os))))

###########################################################################
# SDK: Python
###########################################################################


ifeq ($(os),macOS)
# macOS builds are extracted from the official installer package, then
# reprocessed into an XCFramework.

PYTHON_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_FRAMEWORK-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/Python.framework
PYTHON_INSTALL_VERSION-$(sdk)=$$(PYTHON_FRAMEWORK-$(sdk))/Versions/$(PYTHON_VER)
PYTHON_LIB-$(sdk)=$$(PYTHON_INSTALL_VERSION-$(sdk))/Python
PYTHON_INCLUDE-$(sdk)=$$(PYTHON_INSTALL_VERSION-$(sdk))/include/python$(PYTHON_VER)
PYTHON_STDLIB-$(sdk)=$$(PYTHON_INSTALL_VERSION-$(sdk))/lib/python$(PYTHON_VER)

else
# Non-macOS builds need to be merged on a per-SDK basis. The merge covers:
# * Merging a fat libPython
# * Installing an architecture-sensitive pyconfig.h
# * Merging fat versions of the standard library lib-dynload folder
# The non-macOS frameworks don't use the versioning structure.

PYTHON_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/python-$(PYTHON_VERSION)
PYTHON_FRAMEWORK-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/Python.framework
PYTHON_LIB-$(sdk)=$$(PYTHON_FRAMEWORK-$(sdk))/Python
PYTHON_BIN-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/bin
PYTHON_INCLUDE-$(sdk)=$$(PYTHON_FRAMEWORK-$(sdk))/Headers
PYTHON_STDLIB-$(sdk)=$$(PYTHON_INSTALL-$(sdk))/lib/python$(PYTHON_VER)

$$(PYTHON_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_LIB-$$(target)))
	@echo ">>> Build Python fat library for the $(sdk) SDK"
	mkdir -p $$(dir $$(PYTHON_LIB-$(sdk)))
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/python-$(PYTHON_VERSION).lipo.log

$$(PYTHON_FRAMEWORK-$(sdk))/Info.plist: $$(PYTHON_LIB-$(sdk))
	@echo ">>> Install Info.plist for the $(sdk) SDK"
	# Copy Info.plist as-is from the first target in the $(sdk) SDK
	cp -r $$(PYTHON_FRAMEWORK-$$(firstword $$(SDK_TARGETS-$(sdk))))/Info.plist $$(PYTHON_FRAMEWORK-$(sdk))

$$(PYTHON_INCLUDE-$(sdk))/pyconfig.h: $$(PYTHON_LIB-$(sdk))
	@echo ">>> Build Python fat headers for the $(sdk) SDK"
	# Copy binary helpers from the first target in the $(sdk) SDK
	cp -r $$(PYTHON_BIN-$$(firstword $$(SDK_TARGETS-$(sdk)))) $$(PYTHON_BIN-$(sdk))

	# Create a non-executable stub binary python3
	echo "#!/bin/bash\necho Can\\'t run $(sdk) binary\nexit 1" > $$(PYTHON_BIN-$(sdk))/python$(PYTHON_VER)
	chmod 755 $$(PYTHON_BIN-$(sdk))/python$(PYTHON_VER)

	# Copy headers as-is from the first target in the $(sdk) SDK
	cp -r $$(PYTHON_INCLUDE-$$(firstword $$(SDK_TARGETS-$(sdk)))) $$(PYTHON_INCLUDE-$(sdk))

	# Link the PYTHONHOME version of the headers
	mkdir -p $$(PYTHON_INSTALL-$(sdk))/include
	ln -si ../Python.framework/Headers $$(PYTHON_INSTALL-$(sdk))/include/python$(PYTHON_VER)

	# Add the individual headers from each target in an arch-specific name
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_INCLUDE-$$(target))/pyconfig.h $$(PYTHON_INCLUDE-$(sdk))/pyconfig-$$(ARCH-$$(target)).h; )

	# Copy the cross-target header from the source folder of the first target in the $(sdk) SDK
	cp $$(PYTHON_SRCDIR-$$(firstword $$(SDK_TARGETS-$(sdk))))/$(os)/Resources/pyconfig.h $$(PYTHON_INCLUDE-$(sdk))/pyconfig.h


$$(PYTHON_STDLIB-$(sdk))/LICENSE.TXT: $$(PYTHON_LIB-$(sdk)) $$(PYTHON_FRAMEWORK-$(sdk))/Info.plist $$(PYTHON_INCLUDE-$(sdk))/pyconfig.h
	@echo ">>> Build Python stdlib for the $(sdk) SDK"
	mkdir -p $$(PYTHON_STDLIB-$(sdk))/lib-dynload
	# Copy stdlib from the first target associated with the $(sdk) SDK
	cp -r $$(PYTHON_STDLIB-$$(firstword $$(SDK_TARGETS-$(sdk))))/ $$(PYTHON_STDLIB-$(sdk))

	# Delete the single-SDK parts of the standard library
	rm -rf \
		$$(PYTHON_STDLIB-$(sdk))/_sysconfigdata__*.py \
		$$(PYTHON_STDLIB-$(sdk))/config-* \
		$$(PYTHON_STDLIB-$(sdk))/lib-dynload/*

	# Copy the individual _sysconfigdata modules into names that include the architecture
	$$(foreach target,$$(SDK_TARGETS-$(sdk)),cp $$(PYTHON_STDLIB-$$(target))/_sysconfigdata_* $$(PYTHON_STDLIB-$(sdk))/; )

	# Merge the binary modules from each target in the $(sdk) SDK into a single binary
	$$(foreach module,$$(wildcard $$(PYTHON_STDLIB-$$(firstword $$(SDK_TARGETS-$(sdk))))/lib-dynload/*),lipo -create -output $$(PYTHON_STDLIB-$(sdk))/lib-dynload/$$(notdir $$(module)) $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(PYTHON_STDLIB-$$(target))/lib-dynload/$$(notdir $$(module))); )

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
	@echo "LDFLAGS-$(sdk): $$(LDFLAGS-$(sdk))"
	@echo "PYTHON_INSTALL-$(sdk): $$(PYTHON_INSTALL-$(sdk))"
	@echo "PYTHON_FRAMEWORK-$(sdk): $$(PYTHON_FRAMEWORK-$(sdk))"
	@echo "PYTHON_LIB-$(sdk): $$(PYTHON_LIB-$(sdk))"
	@echo "PYTHON_BIN-$(sdk): $$(PYTHON_BIN-$(sdk))"
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


# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: Python
###########################################################################


PYTHON_XCFRAMEWORK-$(os)=support/$(PYTHON_VER)/$(os)/Python.xcframework

ifeq ($(os),macOS)

PYTHON_FRAMEWORK-$(os)=$$(PYTHON_INSTALL-$(sdk))/Python.framework

$$(PYTHON_XCFRAMEWORK-$(os))/Info.plist: \
		downloads/python-$(PYTHON_PKG_VERSION)-macos11.pkg
	@echo ">>> Repackage macOS package as XCFramework"

	# Unpack .pkg file. It turns out .pkg files are readable by tar... although
	# their internal format is a bit of a mess. From tar's perspective, the .pkg
	# is a tarball that contains additional tarballs; the inner tarball has the
	# "payload" that is the framework.
	mkdir -p build/macOS/macosx/python-$(PYTHON_VERSION)
	tar zxf downloads/python-$(PYTHON_PKG_VERSION)-macos11.pkg -C build/macOS/macosx/python-$(PYTHON_VERSION)

	# Unpack payload inside .pkg file
	mkdir -p $$(PYTHON_FRAMEWORK-macosx)
	tar zxf build/macOS/macosx/python-$(PYTHON_VERSION)/Python_Framework.pkgPython_Framework.pkg/PayloadPython_Framework.pkgPython_Framework.pkg/PayloadPython_Framework.pkgPython_Framework.pkg/Payload -C $$(PYTHON_FRAMEWORK-macosx) -X patch/Python/release.macOS.exclude

	# Apply the App Store compliance patch
	patch --strip 2 --directory $$(PYTHON_INSTALL_VERSION-macosx)/lib/python$(PYTHON_VER) --input $(PROJECT_DIR)/patch/Python/app-store-compliance.patch

	# Rewrite the framework to make it standalone
	patch/make-relocatable.sh $$(PYTHON_INSTALL_VERSION-macosx) 2>&1 > /dev/null

	# Re-apply the signature on the binaries.
	codesign -s - --preserve-metadata=identifier,entitlements,flags,runtime -f $$(PYTHON_LIB-macosx) \
		2>&1 | tee $$(PYTHON_INSTALL-macosx)/python-$(os).codesign.log
	find $$(PYTHON_FRAMEWORK-macosx) -name "*.dylib" -type f -exec codesign -s - --preserve-metadata=identifier,entitlements,flags,runtime -f {} \; \
		2>&1 | tee -a $$(PYTHON_INSTALL-macosx)/python-$(os).codesign.log
	find $$(PYTHON_FRAMEWORK-macosx) -name "*.so" -type f -exec codesign -s - --preserve-metadata=identifier,entitlements,flags,runtime -f {} \; \
		2>&1 | tee -a $$(PYTHON_INSTALL-macosx)/python-$(os).codesign.log
	codesign -s - --preserve-metadata=identifier,entitlements,flags,runtime -f $$(PYTHON_FRAMEWORK-macosx) \
		2>&1 | tee -a $$(PYTHON_INSTALL-macosx)/python-$(os).codesign.log

	# Create XCFramework out of the extracted framework
	xcodebuild -create-xcframework -output $$(PYTHON_XCFRAMEWORK-$(os)) -framework $$(PYTHON_FRAMEWORK-macosx) \
		2>&1 | tee $$(PYTHON_INSTALL-macosx)/python-$(os).xcframework.log

support/$(PYTHON_VER)/macOS/VERSIONS:
	@echo ">>> Create VERSIONS file for macOS"
	echo "Python version: $(PYTHON_VERSION) " > support/$(PYTHON_VER)/macOS/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> support/$(PYTHON_VER)/macOS/VERSIONS
	echo "Min macOS version: $$(VERSION_MIN-macOS)" >> support/$(PYTHON_VER)/macOS/VERSIONS

dist/Python-$(PYTHON_VER)-macOS-support.$(BUILD_NUMBER).tar.gz: \
	$$(PYTHON_XCFRAMEWORK-macOS)/Info.plist \
	support/$(PYTHON_VER)/macOS/VERSIONS \
	$$(foreach target,$$(TARGETS-macOS), $$(PYTHON_SITECUSTOMIZE-$$(target)))

	@echo ">>> Create final distribution artefact for macOS"
	mkdir -p dist
	# Build a distributable tarball
	tar zcvf $$@ -C support/$(PYTHON_VER)/macOS `ls -A support/$(PYTHON_VER)/macOS/`

else

$$(PYTHON_XCFRAMEWORK-$(os))/Info.plist: \
		$$(foreach sdk,$$(SDKS-$(os)),$$(PYTHON_STDLIB-$$(sdk))/LICENSE.TXT)
	@echo ">>> Create Python.XCFramework on $(os)"
	mkdir -p $$(dir $$(PYTHON_XCFRAMEWORK-$(os)))
	xcodebuild -create-xcframework \
		-output $$(PYTHON_XCFRAMEWORK-$(os)) $$(foreach sdk,$$(SDKS-$(os)),-framework $$(PYTHON_FRAMEWORK-$$(sdk))) \
		2>&1 | tee -a support/$(PYTHON_VER)/python-$(os).xcframework.log

	@echo ">>> Install PYTHONHOME for $(os)"
	$$(foreach sdk,$$(SDKS-$(os)),cp -r $$(PYTHON_INSTALL-$$(sdk))/include $$(PYTHON_XCFRAMEWORK-$(os))/$$(SDK_SLICE-$$(sdk)); )
	$$(foreach sdk,$$(SDKS-$(os)),cp -r $$(PYTHON_INSTALL-$$(sdk))/bin $$(PYTHON_XCFRAMEWORK-$(os))/$$(SDK_SLICE-$$(sdk)); )
	$$(foreach sdk,$$(SDKS-$(os)),cp -r $$(PYTHON_INSTALL-$$(sdk))/lib $$(PYTHON_XCFRAMEWORK-$(os))/$$(SDK_SLICE-$$(sdk)); )

	@echo ">>> Create helper links in XCframework for $(os)"
	$$(foreach sdk,$$(SDKS-$(os)),ln -si $$(SDK_SLICE-$$(sdk)) $$(PYTHON_XCFRAMEWORK-$(os))/$$(sdk); )

	@echo ">>> Create VERSIONS file for $(os)"
	echo "Python version: $(PYTHON_VERSION) " > support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Build: $(BUILD_NUMBER)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "Min $(os) version: $$(VERSION_MIN-$(os))" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "---------------------" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "BZip2: $(BZIP2_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "libFFI: $(LIBFFI_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "mpdecimal: $(MPDECIMAL_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "OpenSSL: $(OPENSSL_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS
	echo "XZ: $(XZ_VERSION)" >> support/$(PYTHON_VER)/$(os)/VERSIONS

dist/Python-$(PYTHON_VER)-$(os)-support.$(BUILD_NUMBER).tar.gz: \
	$$(PYTHON_XCFRAMEWORK-$(os))/Info.plist \
	$$(foreach target,$$(TARGETS-$(os)), $$(PYTHON_SITECUSTOMIZE-$$(target)))

	@echo ">>> Create final distribution artefact for $(os)"
	mkdir -p dist
	# Build a distributable tarball
	tar zcvf $$@ -X patch/Python/release.$(os).exclude -C support/$(PYTHON_VER)/$(os) `ls -A support/$(PYTHON_VER)/$(os)/`

endif

clean-$(os):
	@echo ">>> Clean Python build products on $(os)"
	rm -rf \
		build/$(os)/*/python-$(PYTHON_VER)* \
		build/$(os)/*/python-$(PYTHON_VER)*.*.log \
		install/$(os)/*/python-$(PYTHON_VER)* \
		install/$(os)/*/python-$(PYTHON_VER)*.*.log \
		support/$(PYTHON_VER)/$(os) \
		support/$(PYTHON_VER)/python-$(os).*.log \
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

config:
	@echo "PYTHON_VERSION=$(PYTHON_VERSION)"
	@echo "PYTHON_VER=$(PYTHON_VER)"
	@echo "BUILD_NUMBER=$(BUILD_NUMBER)"
	@echo "BZIP2_VERSION=$(BZIP2_VERSION)"
	@echo "LIBFFI_VERSION=$(LIBFFI_VERSION)"
	@echo "MPDECIMAL_VERSION=$(MPDECIMAL_VERSION)"
	@echo "OPENSSL_VERSION=$(OPENSSL_VERSION)"
	@echo "XZ_VERSION=$(XZ_VERSION)"

# Expand cross-platform build and clean targets for each output product
clean: $(foreach os,$(OS_LIST),clean-$(os))
dev-clean: $(foreach os,$(OS_LIST),dev-clean-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
