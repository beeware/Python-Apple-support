PROJECTDIR=$(shell pwd)

BUILD_NUMBER=3

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=3.4.2

OPENSSL_VERSION_NUMBER=1.0.2
OPENSSL_REVISION=d
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

OS=	iOS tvOS watchOS
TARGETS-iOS=		iphonesimulator.x86_64 iphonesimulator.i386\
			iphoneos.armv7 iphoneos.armv7s iphoneos.arm64
CFLAGS-iOS=		-miphoneos-version-min=7.0
CFLAGS-iphoneos.armv7=	-fembed-bitcode
CFLAGS-iphoneos.armv7s=	-fembed-bitcode
CFLAGS-iphoneos.arm64=	-fembed-bitcode

TARGETS-tvOS=		appletvsimulator.x86_64 appletvos.arm64
CFLAGS-tvOS=		-mtvos-version-min=9.0
CFLAGS-appletvos.arm64=	-fembed-bitcode

TARGETS-watchOS=	watchsimulator.i386 watchos.armv7k
CFLAGS-watchOS=		-mwatchos-version-min=2.0
CFLAGS-watchos.armv7=	-fembed-bitcode

all: $(foreach os,$(OS),Python-$(PYTHON_VERSION)-$(os)-support.b$(BUILD_NUMBER).tar.gz)

# Clean all builds
clean:
	rm -rf build dist $(foreach os,$(OS),Python-$(PYTHON_VERSION)-$(os)-support.b$(BUILD_NUMBER).tar.gz)

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
	rm -rf build/OpenSSL
	rm -rf dist/OpenSSL.framework

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz:
	mkdir downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi

define build-openssl-target
ARCH-$1=	$$(subst .,,$$(suffix $1))
SDK-$1=		$$(basename $1)

SDK_ROOT-$1=	$$(shell xcrun --sdk $$(SDK-$1) --show-sdk-path)
CC-$1=		$$(shell xcrun -find -sdk $$(SDK-$1) clang)\
		-arch $$(ARCH-$1) --sysroot=$$(SDK_ROOT-$1) $$(CFLAGS-$2) $$(CFLAGS-$1)

build/OpenSSL/$1/Makefile: downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	mkdir -p build/OpenSSL/$1
	tar zxf downloads/openssl-$(OPENSSL_VERSION).tgz --strip-components 1 -C build/OpenSSL/$1
ifeq ($$(findstring simulator,$$(SDK-$1)),)
	# Tweak ui_openssl.c
	sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" build/OpenSSL/$1/crypto/ui/ui_openssl.c
endif
ifeq ($$(findstring iphone,$$(SDK-$1)),)
	# Patch apps/speed.c to not use fork() since it's not available on tvOS
	sed -ie 's/define HAVE_FORK 1/define HAVE_FORK 0/' build/OpenSSL/$1/apps/speed.c
	# Patch Configure to build for tvOS or watchOS, not iOS
	LANG=C sed -ie 's/-D_REENTRANT:iOS/-D_REENTRANT:$2/' build/OpenSSL/$1/Configure
endif
	# Configure the build
	cd build/OpenSSL/$1 && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		./Configure iphoneos-cross no-asm --openssldir=$(PROJECTDIR)/build/OpenSSL/$1

build/OpenSSL/$1/libssl.a build/OpenSSL/$1/libcrypto.a: build/OpenSSL/$1/Makefile
	# Make the build
	cd build/OpenSSL/$1 && \
		CC="$$(CC-$1)" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$1)).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$1))" \
		make all

vars-$1:
	@echo "ARCH-$1: $$(ARCH-$1)"
	@echo "SDK-$1: $$(SDK-$1)"
	@echo "SDK_ROOT-$1: $$(SDK_ROOT-$1)"
	@echo "CC-$1: $$(CC-$1)"
endef

define build-openssl
$$(foreach target,$$(TARGETS-$1),$$(eval $$(call build-openssl-target,$$(target),$1)))

Python-$(PYTHON_VERSION)-$1-support.b$(BUILD_NUMBER).tar.gz: dist/$1/OpenSSL.framework dist/$1/Python.framework
	tar zcvf $$@ -C dist/$1 Python.framework OpenSSL.framework

build/OpenSSL/$1/libssl.a: $$(foreach target,$$(TARGETS-$1),build/OpenSSL/$$(target)/libssl.a)
	mkdir -p build/OpenSSL/$1
	lipo -create $$^ -output $$@

build/OpenSSL/$1/libcrypto.a: $$(foreach target,$$(TARGETS-$1),build/OpenSSL/$$(target)/libcrypto.a)
	mkdir -p build/OpenSSL/$1
	lipo -create $$^ -output $$@

dist/$1/OpenSSL.framework: build/OpenSSL/$1/libssl.a build/OpenSSL/$1/libcrypto.a
	# Create framework directory structure
	mkdir -p dist/$1/OpenSSL.framework/Versions/$(OPENSSL_VERSION)
	ln -fs $(OPENSSL_VERSION) dist/$1/OpenSSL.framework/Versions/Current

	# Copy the headers (use the version from the simulator because reasons)
	cp -r build/OpenSSL/$$(firstword $$(TARGETS-$1))/include dist/$1/OpenSSL.framework/Versions/Current/Headers

	# Link the current Headers to the top level
	ln -fs Versions/Current/Headers dist/$1/OpenSSL.framework

	# Create the fat library
	$(shell xcrun -find libtool) -no_warning_for_no_symbols -static \
		-o dist/$1/OpenSSL.framework/Versions/Current/OpenSSL \
		build/OpenSSL/$1/libcrypto.a \
		build/OpenSSL/$1/libssl.a

	# Link the fat Library to the top level
	ln -fs Versions/Current/OpenSSL dist/$1/OpenSSL.framework
endef

$(foreach os,$(OS),$(eval $(call build-openssl,$(os))))

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf build/Python-$(PYTHON_VERSION)
	rm -rf build/python
	rm -rf dist/Python.framework

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz:
	mkdir downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

build/Python-$(PYTHON_VERSION)/Makefile: downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack sources
	mkdir build
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz -C build
	# Apply patches
	cd build/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/Python.patch
	cd build/Python-$(PYTHON_VERSION) && cp ../../patch/Python/Setup.embedded Modules/Setup.embedded

#build/Python-$(PYTHON_VERSION)/Python.framework: dist/OpenSSL.framework build/Python-$(PYTHON_VERSION)/Makefile
build/Python-$(PYTHON_VERSION)/iOS/Python.framework: build/Python-$(PYTHON_VERSION)/Makefile
	# Configure and make the build
	cd build/Python-$(PYTHON_VERSION)/iOS && make

dist/Python.framework: build/Python-$(PYTHON_VERSION)/Python.framework
	mkdir dist
	mv build/Python-$(PYTHON_VERSION)/Python.framework dist
