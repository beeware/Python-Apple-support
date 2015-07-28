PROJECTDIR=$(shell pwd)

BUILD_NUMBER=3

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=3.4.2

OPENSSL_VERSION_NUMBER=1.0.2
OPENSSL_REVISION=d
OPENSSL_VERSION=$(OPENSSL_VERSION_NUMBER)$(OPENSSL_REVISION)

# 32 bit iOS Simulator build commands and flags
IOS_SIMULATOR_SDK_ROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)
IOS_SIMULATOR_CC=$(shell xcrun -find -sdk iphonesimulator clang) -arch i386 --sysroot=$(IOS_SIMULATOR_SDK_ROOT) -miphoneos-version-min=7.0

# 64 bit iOS Simulator build commands and flags
IOS_SIMULATOR_64_SDK_ROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)
IOS_SIMULATOR_64_CC=$(shell xcrun -find -sdk iphonesimulator clang) -arch x86_64 --sysroot=$(IOS_SIMULATOR_64_SDK_ROOT) -miphoneos-version-min=7.0

# iOS ARMV7 build commands and flags
IOS_ARMV7_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOS_ARMV7_CC=$(shell xcrun -find -sdk iphoneos clang) -arch armv7 --sysroot=$(IOS_ARMV7_SDK_ROOT) -miphoneos-version-min=7.0

# iOS ARMV7S build commands and flags
IOS_ARMV7S_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOS_ARMV7S_CC=$(shell xcrun -find -sdk iphoneos clang) -arch armv7s --sysroot=$(IOS_ARMV7S_SDK_ROOT) -miphoneos-version-min=7.0

# iOS ARM64 build commands and flags
IOS_ARM64_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOS_ARM64_CC=$(shell xcrun -find -sdk iphoneos clang) -arch arm64 --sysroot=$(IOS_ARM64_SDK_ROOT) -miphoneos-version-min=7.0


all: Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz

# Clean all builds
clean:
	rm -rf build dist Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz: dist/OpenSSL.framework dist/Python.framework
	cd dist && tar zcvf ../Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz Python.framework OpenSSL.framework

###########################################################################
# Working directories
###########################################################################

downloads:
	mkdir -p downloads

build:
	mkdir -p build

dist:
	mkdir -p dist

###########################################################################
# OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Clean the OpenSSL project
clean-OpenSSL:
	rm -rf build/openssl-$(OPENSSL_VERSION)
	rm -rf dist/OpenSSL.framework

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tgz: downloads
	-if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi
	if [ ! -e downloads/openssl-$(OPENSSL_VERSION).tgz ]; then curl --fail -L http://openssl.org/source/old/$(OPENSSL_VERSION_NUMBER)/openssl-$(OPENSSL_VERSION).tar.gz -o downloads/openssl-$(OPENSSL_VERSION).tgz; fi

build/OpenSSL/ios-simulator-i386/libssl.a: build downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/openssl-$(OPENSSL_VERSION).tgz
	cd build && mv openssl-$(OPENSSL_VERSION) ios-simulator-i386
	mkdir -p build/OpenSSL
	cd build && mv ios-simulator-i386 OpenSSL
	# Tweak the Makefile to include sysroot and iOS minimum version
	cd build/OpenSSL/ios-simulator-i386 && \
		sed -ie "s!^CFLAG=!CFLAG=-isysroot $(IOS_SIMULATOR_SDK_ROOT) -arch i386 -miphoneos-version-min=7.0 !" Makefile
	# Configure the build
	cd build/OpenSSL/ios-simulator-i386 && \
		CC="$(IOS_SIMULATOR_CC)" \
		CROSS_TOP="$(dir $(IOS_SIMULATOR_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_SIMULATOR_SDK_ROOT))" \
		./Configure iphoneos-cross --openssldir=$(PROJECTDIR)/build/OpenSSL/ios-simulator-i386
	# Make the build
	cd build/OpenSSL/ios-simulator-i386 && \
		CC="$(IOS_SIMULATOR_CC)" \
		CROSS_TOP="$(dir $(IOS_SIMULATOR_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_SIMULATOR_SDK_ROOT))" \
		make all

build/OpenSSL/ios-simulator-x86_64/libssl.a: build downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/openssl-$(OPENSSL_VERSION).tgz
	cd build && mv openssl-$(OPENSSL_VERSION) ios-simulator-x86_64
	mkdir -p build/OpenSSL
	cd build && mv ios-simulator-x86_64 OpenSSL
	# Tweak the Makefile to include sysroot and iOS minimum version
	cd build/OpenSSL/ios-simulator-x86_64 && \
		sed -ie "s!^CFLAG=!CFLAG=-isysroot $(IOS_SIMULATOR_64_SDK_ROOT) -arch x86_64 -miphoneos-version-min=7.0 !" Makefile
	# Configure the build
	cd build/OpenSSL/ios-simulator-x86_64 && \
		CC="$(IOS_SIMULATOR_64_CC)" \
		CROSS_TOP="$(dir $(IOS_SIMULATOR_64_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_SIMULATOR_64_SDK_ROOT))" \
		./Configure darwin64-x86_64-cc --openssldir=$(PROJECTDIR)/build/OpenSSL/ios-simulator-x86_64
	# Make the build
	cd build/OpenSSL/ios-simulator-x86_64 && \
		CC="$(IOS_SIMULATOR_64_CC)" \
		CROSS_TOP="$(dir $(IOS_SIMULATOR_64_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_SIMULATOR_64_SDK_ROOT))" \
		make all

build/OpenSSL/ios-armv7/libssl.a: build downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/openssl-$(OPENSSL_VERSION).tgz
	cd build && mv openssl-$(OPENSSL_VERSION) ios-armv7
	mkdir -p build/OpenSSL
	cd build && mv ios-armv7 OpenSSL
	# Tweak the Makefile to include sysroot and iOS minimum version
	cd build/OpenSSL/ios-armv7 && \
		sed -ie "s!^CFLAG=!CFLAG=-isysroot $(IOS_ARMV7_SDK_ROOT) -arch armv7 -miphoneos-version-min=7.0 !" Makefile
	# Tweak ui_openssl.c
	cd build/OpenSSL/ios-armv7 && \
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" crypto/ui/ui_openssl.c
	# Configure the build
	cd build/OpenSSL/ios-armv7 && \
		CC="$(IOS_ARMV7_CC)" \
		CROSS_TOP="$(dir $(IOS_ARMV7_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARMV7_SDK_ROOT))" \
		./Configure iphoneos-cross --openssldir=$(PROJECTDIR)/build/OpenSSL/ios-armv7
	# Make the build
	cd build/OpenSSL/ios-armv7 && \
		CC="$(IOS_ARMV7_CC)" \
		CROSS_TOP="$(dir $(IOS_ARMV7_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARMV7_SDK_ROOT))" \
		make all

build/OpenSSL/ios-armv7s/libssl.a: build downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/openssl-$(OPENSSL_VERSION).tgz
	cd build && mv openssl-$(OPENSSL_VERSION) ios-armv7s
	mkdir -p build/OpenSSL
	cd build && mv ios-armv7s OpenSSL
	# Tweak the Makefile to include sysroot and iOS minimum version
	cd build/OpenSSL/ios-armv7s && \
		sed -ie "s!^CFLAG=!CFLAG=-isysroot $(IOS_ARMV7S_SDK_ROOT) -arch armv7s -miphoneos-version-min=7.0 !" Makefile
	# Tweak ui_openssl.c
	cd build/OpenSSL/ios-armv7s && \
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" crypto/ui/ui_openssl.c
	# Configure the build
	cd build/OpenSSL/ios-armv7s && \
		CC="$(IOS_ARMV7S_CC)" \
		CROSS_TOP="$(dir $(IOS_ARMV7S_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARMV7S_SDK_ROOT))" \
		./Configure iphoneos-cross --openssldir=$(PROJECTDIR)/build/OpenSSL/ios-armv7s
	# Make the build
	cd build/OpenSSL/ios-armv7s && \
		CC="$(IOS_ARMV7S_CC)" \
		CROSS_TOP="$(dir $(IOS_ARMV7S_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARMV7S_SDK_ROOT))" \
		make all

build/OpenSSL/ios-arm64/libssl.a: build downloads/openssl-$(OPENSSL_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/openssl-$(OPENSSL_VERSION).tgz
	cd build && mv openssl-$(OPENSSL_VERSION) ios-arm64
	mkdir -p build/OpenSSL
	cd build && mv ios-arm64 OpenSSL
	# Tweak the Makefile to include sysroot and iOS minimum version
	cd build/OpenSSL/ios-arm64 && \
		sed -ie "s!^CFLAG=!CFLAG=-isysroot $(IOS_ARM64_SDK_ROOT) -arch arm64 -miphoneos-version-min=7.0 !" Makefile
	# Tweak ui_openssl.c
	cd build/OpenSSL/ios-arm64 && \
		sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" crypto/ui/ui_openssl.c
	# Configure the build
	cd build/OpenSSL/ios-arm64 && \
		CC="$(IOS_ARM64_CC)" \
		CROSS_TOP="$(dir $(IOS_ARM64_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARM64_SDK_ROOT))" \
		./Configure iphoneos-cross --openssldir=$(PROJECTDIR)/build/OpenSSL/ios-arm64
	# Make the build
	cd build/OpenSSL/ios-arm64 && \
		CC="$(IOS_ARM64_CC)" \
		CROSS_TOP="$(dir $(IOS_ARM64_SDK_ROOT)).." \
		CROSS_SDK="$(notdir $(IOS_ARM64_SDK_ROOT))" \
		make all

build/OpenSSL/libssl.a: \
			build/OpenSSL/ios-simulator-i386/libssl.a \
			build/OpenSSL/ios-simulator-x86_64/libssl.a \
			build/OpenSSL/ios-armv7/libssl.a \
			build/OpenSSL/ios-armv7s/libssl.a \
			build/OpenSSL/ios-arm64/libssl.a
	cd build/OpenSSL && \
		lipo -create \
			ios-simulator-i386/libssl.a \
			ios-simulator-x86_64/libssl.a \
			ios-armv7/libssl.a \
			ios-armv7s/libssl.a \
			ios-arm64/libssl.a \
			-output libssl.a

build/OpenSSL/libcrypto.a: \
			build/OpenSSL/ios-simulator-i386/libssl.a \
			build/OpenSSL/ios-simulator-x86_64/libssl.a \
			build/OpenSSL/ios-armv7/libssl.a \
			build/OpenSSL/ios-armv7s/libssl.a \
			build/OpenSSL/ios-arm64/libssl.a
	cd build/OpenSSL && \
		lipo -create \
			ios-simulator-i386/libcrypto.a \
			ios-simulator-x86_64/libcrypto.a \
			ios-armv7/libcrypto.a \
			ios-armv7s/libcrypto.a \
			ios-arm64/libcrypto.a \
			-output libcrypto.a

dist/OpenSSL.framework: dist build/OpenSSL/libssl.a build/OpenSSL/libcrypto.a
	# Create framework directory structure
	cd dist && mkdir -p OpenSSL.framework
	cd dist && mkdir -p OpenSSL.framework/Versions/$(OPENSSL_VERSION)/
	cd dist/OpenSSL.framework/Versions && ln -fs $(OPENSSL_VERSION) Current

	# Copy the headers (use the version from the x86_64 simulator because reasons)
	cp -r build/OpenSSL/ios-simulator-x86_64/include dist/OpenSSL.framework/Versions/Current/Headers

	# Link the current Headers to the top level
	cd dist/OpenSSL.framework && ln -fs Versions/Current/Headers

	# Create the fat library
	libtool -no_warning_for_no_symbols -static \
		-o dist/OpenSSL.framework/Versions/Current/OpenSSL \
		build/OpenSSL/libcrypto.a \
		build/OpenSSL/libssl.a

	# Link the fat Library to the top level
	cd dist/OpenSSL.framework && ln -fs Versions/Current/OpenSSL

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf build/Python-$(PYTHON_VERSION)
	rm -rf build/python
	rm -rf dist/Python.framework

# Download original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz: downloads
	if [ ! -e downloads/Python-$(PYTHON_VERSION).tgz ]; then curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz; fi

# build/Python-$(PYTHON_VERSION)/Python.framework: build dist/OpenSSL.framework downloads/Python-$(PYTHON_VERSION).tgz
build/Python-$(PYTHON_VERSION)/Python.framework: build downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack sources
	cd build && tar zxf ../downloads/Python-$(PYTHON_VERSION).tgz
	# Apply patches
	cd build/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/Python.patch
	cd build/Python-$(PYTHON_VERSION) && cp ../../patch/Python/Setup.embedded Modules/Setup.embedded
	# Configure and make the build
	cd build/Python-$(PYTHON_VERSION)/iOS && make

dist/Python.framework: dist build/Python-$(PYTHON_VERSION)/Python.framework
	cd dist && mv ../build/Python-$(PYTHON_VERSION)/Python.framework .
