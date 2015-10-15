#
# Useful targets:
# - all-iOS			- build everything for iOS
# - all-tvOS			- build everything for tvOS
# - all-watchOS			- build everything for watchOS
# - OpenSSL.framework-iOS	- build OpenSSL.framework for iOS
# - OpenSSL.framework-tvOS	- build OpenSSL.framework for tvOS
# - OpenSSL.framework-watchOS	- build OpenSSL.framework for watchOS
# - Python-host			- build host python
# - Python.framework-iOS	- build Python.framework for iOS
# - Python.framework-tvOS	- build Python.framework for tvOS
# - Python.framework-watchOS	- build Python.framework for watchOS

# Current director
PROJECT_DIR=$(shell pwd)

BUILD_NUMBER=3

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=	3.4.2
PYTHON_VER=	$(basename $(PYTHON_VERSION))

OPENSSL_VERSION_NUMBER=1.0.2
OPENSSL_REVISION=d
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

# Supported OS
OS=	iOS tvOS watchOS

# iOS targets
TARGETS-iOS=		iphonesimulator.x86_64 iphonesimulator.i386\
			iphoneos.armv7 iphoneos.armv7s iphoneos.arm64
CFLAGS-iOS=		-miphoneos-version-min=7.0
CFLAGS-iphoneos.armv7=	-fembed-bitcode
CFLAGS-iphoneos.armv7s=	-fembed-bitcode
CFLAGS-iphoneos.arm64=	-fembed-bitcode

# tvOS targets
TARGETS-tvOS=		appletvsimulator.x86_64 appletvos.arm64
CFLAGS-tvOS=		-mtvos-version-min=9.0
CFLAGS-appletvos.arm64=	-fembed-bitcode
PYTHON_CONFIGURE-tvOS=	ac_cv_func_sigaltstack=no

# watchOS targets
TARGETS-watchOS=	watchsimulator.i386 watchos.armv7k
CFLAGS-watchOS=		-mwatchos-version-min=2.0
CFLAGS-watchos.armv7k=	-fembed-bitcode
PYTHON_CONFIGURE-watchOS=ac_cv_func_sigaltstack=no

all: $(foreach os,$(OS),all-$(os))

# Clean all builds
clean:
	rm -rf build $(foreach os,$(OS),Python-$(PYTHON_VERSION)-$(os)-support.b$(BUILD_NUMBER).tar.gz)

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

downloads: downloads/openssl-$(OPENSSL_VERSION).tgz downloads/Python-$(PYTHON_VERSION).tgz

###########################################################################
# OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	rm -rf build/*/openssl-$(OPENSSL_VERSION)-* build/*/OpenSSL.framework

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	mkdir downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf build/*/Python-$(PYTHON_VERSION)-* build/*/Python.framework

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	mkdir downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

PYTHON_DIR-host=	build/Python-$(PYTHON_VERSION)-host

Python-host: $(PYTHON_DIR-host)/dist/bin/python$(PYTHON_VER)

# Unpack host Python
$(PYTHON_DIR-host)/configure: downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack host Python
	mkdir -p $(PYTHON_DIR-host)
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $(PYTHON_DIR-host)
	# Configure host Python
	cd $(PYTHON_DIR-host) && ./configure --prefix=$(PROJECT_DIR)/$(PYTHON_DIR-host)/dist --without-ensurepip

# Build host Python
$(PYTHON_DIR-host)/dist/bin/python$(PYTHON_VER): $(PYTHON_DIR-host)/Makefile
	# Build host Python
	make -C $(PYTHON_DIR-host) all install

#
# Build for specified target (from $(TARGETS))
#
# Parameters:
# - $1 - target
# - $2 - OS
define build-target
ARCH-$1=	$$(subst .,,$$(suffix $1))
SDK-$1=		$$(basename $1)

SDK_ROOT-$1=	$$(shell xcrun --sdk $$(SDK-$1) --show-sdk-path)
CC-$1=		xcrun --sdk $$(SDK-$1) clang\
		-arch $$(ARCH-$1) --sysroot=$$(SDK_ROOT-$1) $$(CFLAGS-$2) $$(CFLAGS-$1)

OPENSSL_DIR-$1=	build/$2/openssl-$(OPENSSL_VERSION)-$1
PYTHON_DIR-$1=	build/$2/Python-$(PYTHON_VERSION)-$1

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
	LANG=C sed -ie 's/-D_REENTRANT:iOS/-D_REENTRANT:$2/' $$(OPENSSL_DIR-$1)/Configure
endif
	# Configure the build
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		./Configure iphoneos-cross no-asm --openssldir=$(PROJECT_DIR)/$$(OPENSSL_DIR-$1)

# Build OpenSSL
$$(OPENSSL_DIR-$1)/libssl.a $$(OPENSSL_DIR-$1)/libcrypto.a: $$(OPENSSL_DIR-$1)/Makefile
	# Make the build
	cd $$(OPENSSL_DIR-$1) && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		make all

# Unpack Python
$$(PYTHON_DIR-$1)/Makefile: downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack target Python
	mkdir -p $$(PYTHON_DIR-$1)
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz --strip-components 1 -C $$(PYTHON_DIR-$1)
	# Apply target Python patches
	cd $$(PYTHON_DIR-$1) && patch -p1 <$(PROJECT_DIR)/patch/Python/Python.patch
ifeq ($$(findstring iphone,$$(SDK-$1)),)
	cd $$(PYTHON_DIR-$1) && patch -p1 <$(PROJECT_DIR)/patch/Python/Python-tvos.patch
endif
	cp $(PROJECT_DIR)/patch/Python/Setup.embedded $$(PYTHON_DIR-$1)/Modules/Setup.embedded
	# Configure target Python
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-host)/dist/bin:$(PATH) ./configure \
		CC="$$(CC-$1)" LD="$$(CC-$1)" \
		--host=$$(ARCH-$1)-apple-ios --build=x86_64-apple-darwin$(shell uname -r) \
		--prefix=$(PROJECT_DIR)/$$(PYTHON_DIR-$1)/dist \
		--without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip \
		ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
		$$(PYTHON_CONFIGURE-$2)

# Build Python
$$(PYTHON_DIR-$1)/dist/lib/libpython$(PYTHON_VER).a: $$(PYTHON_DIR-$1)/Makefile build/$2/OpenSSL.framework
	# Build target Python
	cd $$(PYTHON_DIR-$1) && PATH=$(PROJECT_DIR)/$(PYTHON_DIR-host)/dist/bin:$(PATH) make all install

# Dump vars (for test)
vars-$1:
	@echo "ARCH-$1: $$(ARCH-$1)"
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

all-$1: Python-$(PYTHON_VERSION)-$1-support.b$(BUILD_NUMBER).tar.gz

clean-$1:
	rm -rf build/$1

Python-$(PYTHON_VERSION)-$1-support.b$(BUILD_NUMBER).tar.gz: build/$1/OpenSSL.framework build/$1/Python.framework
	tar zcvf $$@ -C build/$1 Python.framework OpenSSL.framework

OpenSSL.framework-$1: build/$1/OpenSSL.framework

# Build OpenSSL.framework
build/$1/OpenSSL.framework: build/$1/libssl.a build/$1/libcrypto.a
	# Create framework directory structure
	mkdir -p build/$1/OpenSSL.framework/Versions/$(OPENSSL_VERSION)
	ln -fs $(OPENSSL_VERSION) build/$1/OpenSSL.framework/Versions/Current

	# Copy the headers (use the version from the simulator because reasons)
	cp -r $$(OPENSSL_DIR-$$(firstword $$(TARGETS-$1)))/include build/$1/OpenSSL.framework/Versions/Current/Headers

	# Link the current Headers to the top level
	ln -fs Versions/Current/Headers build/$1/OpenSSL.framework

	# Create the fat library
	xcrun libtool -no_warning_for_no_symbols -static \
		-o build/$1/OpenSSL.framework/Versions/Current/OpenSSL $$^

	# Link the fat Library to the top level
	ln -fs Versions/Current/OpenSSL build/$1/OpenSSL.framework

build/$1/libssl.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libssl.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

build/$1/libcrypto.a: $$(foreach target,$$(TARGETS-$1),$$(OPENSSL_DIR-$$(target))/libcrypto.a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

Python.framework-$1: build/$1/Python.framework

# Build Python.framework
build/$1/Python.framework: build/$1/libpython$(PYTHON_VER).a

# Build libpython fat library
build/$1/libpython$(PYTHON_VER).a: $$(foreach target,$$(TARGETS-$1),$$(PYTHON_DIR-$$(target))/dist/lib/libpython$(PYTHON_VER).a)
	mkdir -p build/$1
	xcrun lipo -create -output $$@ $$^

endef

$(foreach os,$(OS),$(eval $(call build,$(os))))

_framework:
	# Create the framework directory and set it as the current version
	mkdir -p $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/
	cd $(FRAMEWORK_DIR)/Versions && ln -fs $(PYTHON_VERSION) Current

	# Copy the headers. The headers are the same for every platform, except for pyconfig.h;
	# use the x86_64 simulator build because reasons.
	cp -r build/ios-simulator-x86_64/include/python$(PYTHON_VERSION) $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers

	# The only headers that change between versions is pyconfig.h; copy each supported version...
	cp build/ios-simulator-i386/include/python$(PYTHON_VERSION)/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig-i386.h
	cp build/ios-simulator-x86_64/include/python$(PYTHON_VERSION)/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig-x86_64.h
	# ARMv7 and ARMv7S headers are the same; don't copy this one.
	# cp build/ios-armv7s/include/python$(PYTHON_VERSION)/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig-armv7s.h
	cp build/ios-armv7/include/python$(PYTHON_VERSION)/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig-armv7.h
	cp build/ios-arm64/include/python$(PYTHON_VERSION)/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig-arm64.h
	# ... and then copy in a master pyconfig.h to unify them all.
	cp include/pyconfig.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig.h

	# Link the current Headers to the top level
	cd $(FRAMEWORK_DIR) && ln -fs Versions/Current/Headers

	# Copy the standard library from the simulator build. Again, the
	# pure Python standard library is the same on every platform;
	# use the simulator version because reasons.
	mkdir -p $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources
	cp -r build/ios-simulator-x86_64/lib $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources

	# Copy Python.h and pyconfig.h into the resources include directory
	mkdir -p $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/include/python$(PYTHON_VERSION)
	cp -r $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/pyconfig*.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/include/python$(PYTHON_VERSION)
	cp -r $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Headers/Python.h $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/include/python$(PYTHON_VERSION)

	# Remove the pieces of the resources directory that aren't needed:
	# libpython.a isn't needed in the lib directory
	rm -f $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/lib/libpython$(PYTHON_VERSION).a
	# pkgconfig isn't needed on the device
	rm -rf $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/lib/pkgconfig

ifneq ($(TEST),)
	# Do the pruning and compression.
	cd $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Resources/lib/python$(PYTHON_VERSION);
	rm -rf *test* lib* bsddb curses ensurepip hotshot idlelib tkinter turtledemo wsgiref \
		config-$(PYTHON_VERSION) ctypes/test distutils/tests site-packages sqlite3/test; \
	find . -name "*.pyc" -exec rm -rf {} \;
	zip -r ../python$(subst .,,$(PYTHON_VER)).zip *;
endif

	# Link the current Resources to the top level
	cd $(FRAMEWORK_DIR) && ln -fs Versions/Current/Resources

	# Create a fat binary for the libPython library
	cp libpython.a $(FRAMEWORK_DIR)/Versions/$(PYTHON_VERSION)/Python

	# Link the current Python library to the top level
	cd $(FRAMEWORK_DIR) && ln -fs Versions/Current/Python
