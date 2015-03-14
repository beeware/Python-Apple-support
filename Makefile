PROJECTDIR=$(shell pwd)

# iOS Build variables.
OSX_SDK_ROOT=$(shell xcrun --sdk macosx --show-sdk-path)

BUILD_NUMBER=1

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=3.4.2
RUBICON_VERSION=0.1.3

# Build identifier of the build OS.
BUILD_OS_ID=x86_64-apple-darwin$(shell uname -r)

# IOS ARMV7 build commands and flags
IOS_ARMV7_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOS_ARMV7_CC=$(shell xcrun -find -sdk iphoneos clang) -arch armv7 --sysroot=$(IOS_ARMV7_SDK_ROOT) -miphoneos-version-min=6.0
IOS_ARMV7_LD=$(shell xcrun -find -sdk iphoneos ld) -arch armv7 --sysroot=$(IOS_ARMV7_SDK_ROOT) -miphoneos-version-min=6.0

# IOS ARM64 build commands and flags
IOS_ARM64_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IOS_ARM64_CC=$(shell xcrun -find -sdk iphoneos clang) -arch arm64 --sysroot=$(IOS_ARM64_SDK_ROOT) -miphoneos-version-min=6.0
IOS_ARM64_LD=$(shell xcrun -find -sdk iphoneos ld) -arch arm64 --sysroot=$(IOS_ARM64_SDK_ROOT) -miphoneos-version-min=6.0

# IOS_SIMULATOR build commands and flags
IOS_SIMULATOR_SDK_ROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)
IOS_SIMULATOR_CC=$(shell xcrun -find -sdk iphonesimulator clang) -arch x86_64 --sysroot=$(IOS_SIMULATOR_SDK_ROOT) -miphoneos-version-min=6.0
IOS_SIMULATOR_LD=$(shell xcrun -find -sdk iphonesimulator ld) -arch x86_64 --sysroot=$(IOS_SIMULATOR_SDK_ROOT) -miphoneos-version-min=6.0


all: Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz

# Clean all builds
clean:
	rm -rf build dist Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

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
# rubicon-objc
###########################################################################

# Clean the rubicon project
clean-rubicon-objc:
	rm -rf build/rubicon-objc-$(RUBICON_VERSION)

# Down original librubicon-objc source code archive.
downloads/rubicon-objc-$(RUBICON_VERSION).tar.gz: downloads
	curl -L https://github.com/pybee/rubicon-objc/archive/v$(RUBICON_VERSION).tar.gz > downloads/rubicon-objc-$(RUBICON_VERSION).tar.gz

# Unpack rubicon-objc source archive into build working directory
build/rubicon-objc-$(RUBICON_VERSION): downloads/rubicon-objc-$(RUBICON_VERSION).tar.gz
	tar zxf downloads/rubicon-objc-$(RUBICON_VERSION).tar.gz
	mv rubicon-objc-$(RUBICON_VERSION) build

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf build/Python-$(PYTHON_VERSION)
	rm -rf build/python
	rm -rf dist/Python.framework

# Down original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz: downloads
	curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz

build/Python-$(PYTHON_VERSION)/host/python.exe: build downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/host
	# Configure and make the local build, providing compiled resources.
	cd build/Python-$(PYTHON_VERSION)/host && ./configure --prefix=$(PROJECTDIR)/build/python/host
	cd build/Python-$(PYTHON_VERSION)/host && make

build/python/ios-simulator/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-simulator
	# Apply patches
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 < ../../../patch/Python/Python.patch
	# Configure and build Simulator library
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) ./configure --host=x86_64-apple-ios --build=$(BUILD_OS_ID) CC="$(IOS_SIMULATOR_CC)" LD="$(IOS_SIMULATOR_LD)" --prefix=$(PROJECTDIR)/build/python/ios-simulator --without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) make && make install

build/python/ios-armv7/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-armv7
	# Apply patches
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 < ../../../patch/Python/Python.patch
	# Configure and build ARMv7 library
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) ./configure --host=armv7-apple-ios --build=$(BUILD_OS_ID) CC="$(IOS_ARMV7_CC)" LD="$(IOS_ARMV7_LD)" --prefix=$(PROJECTDIR)/build/python/ios-armv7 --without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) make && make install

build/python/ios-arm64/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-arm64
	# Apply patches
	cd build/Python-$(PYTHON_VERSION)/ios-arm64 && patch -p1 < ../../../patch/Python/Python.patch
	# Configure and build ARM64 library
	cd build/Python-$(PYTHON_VERSION)/ios-arm64 && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) ./configure --host=aarch64-apple-ios --build=$(BUILD_OS_ID) CC="$(IOS_ARM64_CC)" LD="$(IOS_ARM64_LD)" --prefix=$(PROJECTDIR)/build/python/ios-arm64 --without-pymalloc --without-doc-strings --disable-ipv6 --without-ensurepip ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no
	cd build/Python-$(PYTHON_VERSION)/ios-arm64 && PATH=$(PROJECTDIR)/build/python/host/bin:$(PATH) make && make install

dist/Python.framework/Python: build/python/ios-simulator/Python build/python/ios-arm64/Python build/rubicon-objc-$(RUBICON_VERSION)
	# Create the framework directory and set it as the current version
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/
	cd dist/Python.framework/Versions && ln -fs $(basename $(PYTHON_VERSION)) Current

	# Copy the headers. The headers are the same for every platform, except for pyconfig.h;
	# use the x86_64 simulator build because reasons.
	cp -r build/python/ios-simulator/include/python$(basename $(PYTHON_VERSION)) dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers
	# The only headers that change between versions is pyconfig.h; copy each supported version...
	cp build/python/ios-simulator/include/python$(basename $(PYTHON_VERSION))/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers/pyconfig-x86_64.h
	cp build/python/ios-arm64/include/python$(basename $(PYTHON_VERSION))/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers/pyconfig-arm64.h
	# cp build/python/ios-armv7/include/python$(basename $(PYTHON_VERSION))/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers/pyconfig-armv7.h
	# ... and then copy in a master pyconfig.h to unify them all.
	cp patch/Python/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers/pyconfig.h

	# Link the current Headers to the top level
	cd dist/Python.framework && ln -fs Versions/Current/Headers

	# Copy the standard library from the x86_64 simulator build. Again, the
	# pure Python standard library is the same on every platform; use the
	# simulator version because reasons.
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources
	cp -r build/python/ios-simulator/lib dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources

	# Remove the pieces of the resources directory that aren't needed:
	# libpython.a isn't needed in the lib directory
	rm -f dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/libpython$(basename $(PYTHON_VERSION)).a
	# pkgconfig isn't needed on the device
	rm -rf dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/pkgconfig
	# Remove all the modules we don't need, compress the rest.
	cd dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *test* lib* bsddb curses ensurepip hotshot idlelib tkinter turtledemo wsgiref config-$(basename $(PYTHON_VERSION)) ctypes/test distutils/tests site-pacakges sqlite3/test
	cd dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/python$(basename $(PYTHON_VERSION)) && zip -r ../python$(subst .,,$(basename $(PYTHON_VERSION))).zip *
	cd dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *

	# Install Rubicon into site packages.
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/python$(basename $(PYTHON_VERSION))/site-packages
	cd build && cp -r rubicon-objc-$(RUBICON_VERSION)/rubicon ../dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/lib/python$(basename $(PYTHON_VERSION))/site-packages/

	# Link the current Resources to the top level
	cd dist/Python.framework && ln -fs Versions/Current/Resources

	# Create a fat binary for the libPython library
	xcrun lipo -create -output \
		dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Python \
		build/python/ios-simulator/lib/libpython$(basename $(PYTHON_VERSION)).a \
		build/python/ios-arm64/lib/libpython$(basename $(PYTHON_VERSION)).a;
		# build/python/ios-armv7/lib/libpython$(basename $(PYTHON_VERSION)).a;

	# Link the current Python library to the top level
	cd dist/Python.framework && ln -fs Versions/Current/Python

Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz: dist/Python.framework/Python
	cd dist && tar zcvf ../Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz Python.framework
