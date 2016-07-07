#
# Useful targets:
# - all                       - build everything
# - macOS                     - build everything for macOS
# - iOS                       - build everything for iOS
# - tvOS                      - build everything for tvOS
# - watchOS                   - build everything for watchOS
# - OpenSSL.framework-macOS   - build OpenSSL.framework for macOS
# - OpenSSL.framework-iOS     - build OpenSSL.framework for iOS
# - OpenSSL.framework-tvOS    - build OpenSSL.framework for tvOS
# - OpenSSL.framework-watchOS - build OpenSSL.framework for watchOS
# - BZip2.framework-macOS     - build BZip2.framework for macOS
# - BZip2.framework-iOS       - build BZip2.framework for iOS
# - BZip2.framework-tvOS      - build BZip2.framework for tvOS
# - BZip2.framework-watchOS   - build BZip2.framework for watchOS
# - Python.framework-macOS    - build Python.framework for macOS
# - Python.framework-iOS      - build Python.framework for iOS
# - Python.framework-tvOS     - build Python.framework for tvOS
# - Python.framework-watchOS  - build Python.framework for watchOS

# Current director
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=1

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=2.7.12
PYTHON_VER=$(basename $(PYTHON_VERSION))

OPENSSL_VERSION_NUMBER=1.0.2
OPENSSL_REVISION=h
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

BZIP2_VERSION=1.0.6

# Supported OS
OS=macOS iOS tvOS watchOS

# macOS targets
TARGETS-macOS=macosx.x86_64

# iOS targets
TARGETS-iOS=iphonesimulator.x86_64 iphonesimulator.i386 iphoneos.armv7 iphoneos.armv7s iphoneos.arm64
CFLAGS-iOS=-miphoneos-version-min=7.0
CFLAGS-iphoneos.armv7=-fembed-bitcode
CFLAGS-iphoneos.armv7s=-fembed-bitcode
CFLAGS-iphoneos.arm64=-fembed-bitcode

# tvOS targets
TARGETS-tvOS=appletvsimulator.x86_64 appletvos.arm64
CFLAGS-tvOS=-mtvos-version-min=9.0
CFLAGS-appletvos.arm64=-fembed-bitcode
PYTHON_CONFIGURE-tvOS=ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=watchsimulator.i386 watchos.armv7k
CFLAGS-watchOS=-mwatchos-version-min=2.0
CFLAGS-watchos.armv7k=-fembed-bitcode
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

downloads: downloads/openssl-$(OPENSSL_VERSION).tgz downloads/bzip2-$(BZIP2_VERSION).tgz downloads/Python-$(PYTHON_VERSION).tgz

###########################################################################
# OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	rm -rf build/*/openssl-$(OPENSSL_VERSION)-* \
		build/*/libssl.a build/*/libcrypto.a \
		build/*/OpenSSL.framework

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

# Download original OpenSSL source code archive.
downloads/bzip2-$(BZIP2_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/bzip2-$(BZIP2_VERSION).tgz ]; then curl --fail -L http://www.bzip.org/$(BZIP2_VERSION)/bzip2-$(BZIP2_VERSION).tar.gz -o downloads/bzip2-$(BZIP2_VERSION).tgz; fi

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf \
		build/*/Python-$(PYTHON_VERSION)-* \
		build/*/libpython$(PYTHON_VER).a \
		build/*/pyconfig-*.h \
		build/*/Python.framework

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
CC-$1=xcrun --sdk $$(SDK-$1) clang\
					-arch $$(ARCH-$1) --sysroot=$$(SDK_ROOT-$1) $$(CFLAGS-$2) $$(CFLAGS-$1)
LDFLAGS-$1=-arch $$(ARCH-$1) -isysroot=$$(SDK_ROOT-$1)

OPENSSL_DIR-$1=build/$2/openssl-$(OPENSSL_VERSION)-$1
BZIP2_DIR-$1=build/$2/bzip2-$(BZIP2_VERSION)-$1
PYTHON_DIR-$1=build/$2/Python-$(PYTHON_VERSION)-$1
pyconfig.h-$1=pyconfig-$$(ARCH-$1).h

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
	# Patch apps/speed.c to not use fork() since it's not available on tvOS
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' $$(OPENSSL_DIR-$1)/apps/speed.c
	# Patch Configure to build for tvOS or watchOS, not iOS
	LC_ALL=C sed -ie 's/-D_REENTRANT:iOS/-D_REENTRANT:$2/' $$(OPENSSL_DIR-$1)/Configure
endif

	# Configure the build
ifeq ($2,macOS)
	cd $$(OPENSSL_DIR-$1) && \
	CC="$$(CC-$1)" \
		./Configure darwin64-x86_64-cc --openssldir=$(PROJECT_DIR)/$$(OPENSSL_DIR-$1)
else
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		./Configure iphoneos-cross no-asm --openssldir=$(PROJECT_DIR)/$$(OPENSSL_DIR-$1)
endif

# Build OpenSSL
$$(OPENSSL_DIR-$1)/libssl.a $$(OPENSSL_DIR-$1)/libcrypto.a: $$(OPENSSL_DIR-$1)/Makefile
	# Make the build
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		make all

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

# Unpack Python
$$(PYTHON_DIR-$1)/Makefile: downloads/Python-$(PYTHON_VERSION).tgz $(PYTHON_HOST)
	# Unpack target Python
	mkdir -p $$(PYTHON_DIR-$1)
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$1)
	# Apply target Python patches
	cd $$(PYTHON_DIR-$1) && patch -p1 < $(PROJECT_DIR)/patch/Python/Python.patch

	# Configure target Python
ifeq ($2,macOS)
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH) ./configure \
		CC="$$(CC-$1)" LD="$$(CC-$1)" \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$1)/dist \
		--without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip \
		$$(PYTHON_CONFIGURE-$2)
else
	cp -f $(PROJECT_DIR)/patch/Python/Setup.embedded $$(PYTHON_DIR-$1)/Modules/Setup.embedded
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH) ./configure \
		CC="$$(CC-$1)" LD="$$(CC-$1)" \
		--host=$$(MACHINE_DETAILED-$1)-apple-ios --build=x86_64-apple-darwin$(shell uname -r) \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$1)/dist \
		--without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip \
		ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
		$$(PYTHON_CONFIGURE-$2)
endif

# Build Python
$$(PYTHON_DIR-$1)/dist/lib/libpython$(PYTHON_VER).a: build/$2/OpenSSL.framework build/$2/BZip2.framework $$(PYTHON_DIR-$1)/Makefile
	# Build target Python
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-macOS)/dist/bin:$(PATH) make all install

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
# Install target pyconfig.h
# Parameters:
# - $1 - target
# - $2 - framework directory
define install-target-pyconfig
endef

#
# Build for specified OS (from $(OS))
# Parameters:
# - $1 - OS
define build
$$(foreach target,$$(TARGETS-$1),$$(eval $$(call build-target,$$(target),$1)))

OPENSSL_FRAMEWORK-$1=build/$1/OpenSSL.framework
BZIP2_FRAMEWORK-$1=build/$1/BZip2.framework
PYTHON_FRAMEWORK-$1=build/$1/Python.framework
PYTHON_RESOURCES-$1=$$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Resources

$1: dist/Python-$(PYTHON_VER)-$1-support.b$(BUILD_NUMBER).tar.gz

clean-$1:
	rm -rf build/$1

dist/Python-$(PYTHON_VER)-$1-support.b$(BUILD_NUMBER).tar.gz: $$(BZIP2_FRAMEWORK-$1) $$(OPENSSL_FRAMEWORK-$1) $$(PYTHON_FRAMEWORK-$1)
	mkdir -p dist
	tar zcvf $$@ -C build/$1 $$(notdir $$^)

# Build OpenSSL.framework
OpenSSL.framework-$1: $$(OPENSSL_FRAMEWORK-$1)

$$(OPENSSL_FRAMEWORK-$1): build/$1/libssl.a build/$1/libcrypto.a
	# Create framework directory structure
	mkdir -p $$(OPENSSL_FRAMEWORK-$1)/Versions/$(OPENSSL_VERSION)

	# Copy the headers
	cp -f -r $$(OPENSSL_DIR-$$(firstword $$(TARGETS-$1)))/include $$(OPENSSL_FRAMEWORK-$1)/Versions/$(OPENSSL_VERSION)/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(OPENSSL_FRAMEWORK-$1)/Versions/$(OPENSSL_VERSION)/OpenSSL $$^

	# Create symlinks
	ln -fs $(OPENSSL_VERSION) $$(OPENSSL_FRAMEWORK-$1)/Versions/Current
	ln -fs Versions/Current/Headers $$(OPENSSL_FRAMEWORK-$1)
	ln -fs Versions/Current/OpenSSL $$(OPENSSL_FRAMEWORK-$1)

build/$1/libssl.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libssl.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

build/$1/libcrypto.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libcrypto.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

# Build BZip2.framework
BZip2.framework-$1: $$(BZIP2_FRAMEWORK-$1)

$$(BZIP2_FRAMEWORK-$1): build/$1/bzip2/lib/libbz2.a
	# Create framework directory structure
	mkdir -p $$(BZIP2_FRAMEWORK-$1)/Versions/$(BZIP2_VERSION)

	# Copy the headers
	cp -f -r build/$1/bzip2/include $$(BZIP2_FRAMEWORK-$1)/Versions/$(BZIP2_VERSION)/Headers

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o $$(BZIP2_FRAMEWORK-$1)/Versions/$(BZIP2_VERSION)/bzip2 $$^

	# Create symlinks
	ln -fs $(BZIP2_VERSION) $$(BZIP2_FRAMEWORK-$1)/Versions/Current
	ln -fs Versions/Current/Headers $$(BZIP2_FRAMEWORK-$1)
	ln -fs Versions/Current/bzip2 $$(BZIP2_FRAMEWORK-$1)

build/$1/bzip2/lib/libbz2.a: $$(foreach target,$$(TARGETS-$1),$$(BZIP2_DIR-$$(target))/libbz2.a)
	mkdir -p build/$1
	xcrun lipo -create -o $$@ $$^

$1: Python.framework-$1

Python.framework-$1: $$(PYTHON_FRAMEWORK-$1)

# Build Python.framework
$$(PYTHON_FRAMEWORK-$1): build/$1/libpython$(PYTHON_VER).a $$(foreach target,$$(TARGETS-$1),build/$1/$$(pyconfig.h-$$(target)))
	mkdir -p $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)

	# Copy the headers. The headers are the same for every platform, except for pyconfig.h
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/dist/include/python$(PYTHON_VER) $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Headers
	cp -f $$(filter %.h,$$^) $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Headers
	cp -f $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/iOS/include/pyconfig.h $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Headers

	# Copy Python.h and pyconfig.h into the resources include directory
	cp -f -r $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Headers/pyconfig*.h $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)
	cp -f -r $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Headers/Python.h $$(PYTHON_RESOURCES-$1)/include/python$(PYTHON_VER)

	# Copy the standard library from the simulator build
ifneq ($(TEST),)
	cp -f -r $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/dist/lib $$(PYTHON_RESOURCES-$1)
	# Remove the pieces of the resources directory that aren't needed:
	rm -f $$(PYTHON_RESOURCES-$1)/lib/libpython$(PYTHON_VER).a
	rm -rf $$(PYTHON_RESOURCES-$1)/lib/pkgconfig
else
	mkdir -p $$(PYTHON_RESOURCES-$1)/lib
	cd $$(PYTHON_DIR-$$(firstword $$(TARGETS-$1)))/dist/lib/python$(PYTHON_VER) && \
		zip -x@$(PROJECT_DIR)/patch/Python/lib-exclude.lst -r $(PROJECT_DIR)/$$(PYTHON_RESOURCES-$1)/lib/python$(subst .,,$(PYTHON_VER)) *
endif

	# Copy fat library
	cp -f $$(filter %.a,$$^) $$(PYTHON_FRAMEWORK-$1)/Versions/$(PYTHON_VER)/Python

	# Create symlinks
	ln -fs $(PYTHON_VER) $$(PYTHON_FRAMEWORK-$1)/Versions/Current
	ln -fs Versions/Current/Headers $$(PYTHON_FRAMEWORK-$1)
	ln -fs Versions/Current/Resources $$(PYTHON_FRAMEWORK-$1)
	ln -fs Versions/Current/Python $$(PYTHON_FRAMEWORK-$1)

# Build libpython fat library
build/$1/libpython$(PYTHON_VER).a: $$(foreach target,$$(TARGETS-$1),$$(PYTHON_DIR-$$(target))/dist/lib/libpython$(PYTHON_VER).a)
	# Create a fat binary for the libPython library
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^
endef

$(foreach os,$(OS),$(eval $(call build,$(os))))
