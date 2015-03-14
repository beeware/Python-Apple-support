PROJECTDIR=$(shell pwd)

# iOS Build variables.
OSX_SDK_ROOT=$(shell xcrun --sdk macosx --show-sdk-path)

BUILD_NUMBER=4

# Version of packages that will be compiled by this meta-package
FFI_VERSION=3.1
PYTHON_VERSION=3.4.2
RUBICON_VERSION=0.1.2

# IPHONE build commands and flags
IPHONE_ARMV7_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IPHONE_ARMV7_CC=$(shell xcrun -find -sdk iphoneos clang)
IPHONE_ARMV7_LD=$(shell xcrun -find -sdk iphoneos ld)
IPHONE_ARMV7_CFLAGS=-arch armv7 -pipe -no-cpp-precomp -isysroot $(IPHONE_ARMV7_SDK_ROOT) -miphoneos-version-min=6.0
IPHONE_ARMV7_LDFLAGS=-arch armv7 -isysroot $(IPHONE_ARMV7_SDK_ROOT) -miphoneos-version-min=6.0

# IPHONE build commands and flags
IPHONE_ARMV7S_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IPHONE_ARMV7S_CC=$(shell xcrun -find -sdk iphoneos clang)
IPHONE_ARMV7S_LD=$(shell xcrun -find -sdk iphoneos ld)
IPHONE_ARMV7S_CFLAGS=-arch armv7s -pipe -no-cpp-precomp -isysroot $(IPHONE_ARMV7S_SDK_ROOT) -miphoneos-version-min=6.0
IPHONE_ARMV7S_LDFLAGS=-arch armv7s -isysroot $(IPHONE_ARMV7S_SDK_ROOT) -miphoneos-version-min=6.0

# IPHONE_SIMULATOR build commands and flags
IPHONE_SIMULATOR_SDK_ROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)
IPHONE_SIMULATOR_CC=$(shell xcrun -find -sdk iphonesimulator clang)
IPHONE_SIMULATOR_LD=$(shell xcrun -find -sdk iphonesimulator ld)
IPHONE_SIMULATOR_CFLAGS=-arch i386 -pipe -no-cpp-precomp -isysroot $(IPHONE_SIMULATOR_SDK_ROOT) -miphoneos-version-min=6.0
IPHONE_SIMULATOR_LDFLAGS=-arch i386 -isysroot $(IPHONE_SIMULATOR_SDK_ROOT) -miphoneos-version-min=6.0


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
# libFFI
###########################################################################

# Clean the libffi project
clean-ffi:
	rm -rf build/libffi-$(FFI_VERSION)
	rm -rf dist/ffi.framework

# Down original libffi source code archive.
downloads/libffi-$(FFI_VERSION).tar.gz: downloads
	curl -L ftp://sourceware.org/pub/libffi/libffi-$(FFI_VERSION).tar.gz > downloads/libffi-$(FFI_VERSION).tar.gz

# Unpack libffi source archive into build working directory
build/libffi-$(FFI_VERSION): build downloads/libffi-$(FFI_VERSION).tar.gz
	tar zxf downloads/libffi-$(FFI_VERSION).tar.gz
	mv libffi-$(FFI_VERSION) build

# Patch and build the framework
dist/ffi.framework/ffi: dist build/libffi-$(FFI_VERSION)
	# Patch the libFFI sources
	cd build/libffi-$(FFI_VERSION) && patch -p1 -N < ../../patch/libffi/generate-darwin-source-and-headers.py.patch
	# Generate headers for iOS platforms
	cd build/libffi-$(FFI_VERSION) && python generate-darwin-source-and-headers.py --only-ios
	# Build all required targets.
	cd build/libffi-$(FFI_VERSION)/build_iphoneos-armv7 && make
	cd build/libffi-$(FFI_VERSION)/build_iphoneos-arm64 && make
	cd build/libffi-$(FFI_VERSION)/build_iphonesimulator-i386 && make
	# Copy the headers into a single directory
	mkdir -p dist/ffi.framework/Versions/${FFI_VERSION}/Headers
	cp build/libffi-$(FFI_VERSION)/darwin_common/include/* dist/ffi.framework/Versions/${FFI_VERSION}/Headers
	cp build/libffi-$(FFI_VERSION)/darwin_ios/include/* dist/ffi.framework/Versions/${FFI_VERSION}/Headers
	# Make the fat binary
	xcrun lipo -create -output dist/ffi.framework/Versions/$(FFI_VERSION)/ffi build/libffi-$(FFI_VERSION)/build_iphoneos-arm64/.libs/libffi.a build/libffi-$(FFI_VERSION)/build_iphoneos-armv7/.libs/libffi.a build/libffi-$(FFI_VERSION)/build_iphonesimulator-i386/.libs/libffi.a
	# Link the Current, Headers and binary.
	cd dist/ffi.framework/Versions && ln -sf ${FFI_VERSION} Current
	cd dist/ffi.framework && ln -sf Versions/Current/Headers
	cd dist/ffi.framework && ln -sf Versions/Current/ffi

###########################################################################
# rubicon-objc
###########################################################################

# Clean the libffi project
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
	rm -rf dist/Python.framework
	rm -rf dist/python

# Down original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tgz: downloads
	curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tgz > downloads/Python-$(PYTHON_VERSION).tgz

build/Python-$(PYTHON_VERSION)/host/python.exe: build downloads/Python-$(PYTHON_VERSION).tgz
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/host
	# Apply patches
	cp patch/Python/ModulesSetup build/Python-$(PYTHON_VERSION)/host/Modules/Setup.local
	cp patch/Python/_scproxy.py build/Python-$(PYTHON_VERSION)/host/Lib/_scproxy.py
	cd build/Python-$(PYTHON_VERSION)/host && patch -p1 -N < ../../../patch/Python/dynload.patch
	cd build/Python-$(PYTHON_VERSION)/host && patch -p1 -N < ../../../patch/Python/ssize-t-max.patch
	cd build/Python-$(PYTHON_VERSION)/host && patch -p1 -N < ../../../patch/Python/static-_sqlite3.patch
	# Configure and make the local build, providing compiled resources.
	cd build/Python-$(PYTHON_VERSION)/host && ./configure CC="clang -Qunused-arguments -fcolor-diagnostics" LDFLAGS="-lsqlite3" CFLAGS="--sysroot=$(OSX_SDK_ROOT)" --prefix=$(PROJECTDIR)/build/Python-$(PYTHON_VERSION)/host/build
	cd build/Python-$(PYTHON_VERSION)/host && make

build/python/ios-simulator/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-simulator
	# Apply patches
	cp patch/Python/ModulesSetup build/Python-$(PYTHON_VERSION)/ios-simulator/Modules/Setup.local
	cat patch/Python/ModulesSetup.mobile >> build/Python-$(PYTHON_VERSION)/ios-simulator/Modules/Setup.local
	cp patch/Python/_scproxy.py build/Python-$(PYTHON_VERSION)/ios-simulator/Lib/_scproxy.py
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 -N < ../../../patch/Python/dynload.patch
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 -N < ../../../patch/Python/ssize-t-max.patch
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 -N < ../../../patch/Python/static-_sqlite3.patch
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 < ../../../patch/Python/xcompile.patch
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 < ../../../patch/Python/setuppath.patch
	# Configure and build Simulator library
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && ./configure CC="$(IPHONE_SIMULATOR_CC)" LD="$(IPHONE_SIMULATOR_LD)" CFLAGS="$(IPHONE_SIMULATOR_CFLAGS) -I../../../dist/ffi.framework/Headers" LDFLAGS="$(IPHONE_SIMULATOR_LDFLAGS) -L../../../dist/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --prefix=$(PROJECTDIR)/build/python/ios-simulator --without-doc-strings
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 < ../../../patch/Python/ctypes_duplicate.patch
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && patch -p1 < ../../../patch/Python/pyconfig.patch
	mkdir -p build/python/ios-simulator
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && cp ../host/python.exe hostpython
	cd build/Python-$(PYTHON_VERSION)/ios-simulator && make altbininstall libinstall inclinstall libainstall HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes
	# Relocate and rename the libpython binary
	cd build/python/ios-simulator/lib && mv libpython$(basename $(PYTHON_VERSION)).a ../Python
	# Clean up build directory
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && rm config/libpython$(basename $(PYTHON_VERSION)).a config/python.o config/config.c.in config/makesetup
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *test* lib* wsgiref bsddb curses idlelib hotshot
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.pyc' | xargs rm
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.py' | xargs rm
	cd build/python/ios-simulator/lib && rm -rf pkgconfig
	# Pack libraries into .zip file
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && mv config ..
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && mv site-packages ..
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && zip -r ../python27.zip *
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && mv ../config .
	cd build/python/ios-simulator/lib/python$(basename $(PYTHON_VERSION)) && mv ../site-packages .
	# Move all headers except for pyconfig.h into a Headers directory
	mkdir -p build/python/ios-simulator/Headers
	cd build/python/ios-simulator/Headers && mv ../include/python$(basename $(PYTHON_VERSION))/* .
	cd build/python/ios-simulator/Headers && mv pyconfig.h ../include/python$(basename $(PYTHON_VERSION))


build/python/ios-armv7/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-armv7
	# Apply extra patches for iPhone build
	cp patch/Python/ModulesSetup build/Python-$(PYTHON_VERSION)/ios-armv7/Modules/Setup.local
	cat patch/Python/ModulesSetup.mobile >> build/Python-$(PYTHON_VERSION)/ios-armv7/Modules/Setup.local
	cp patch/Python/_scproxy.py build/Python-$(PYTHON_VERSION)/ios-armv7/Lib/_scproxy.py
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 -N < ../../../patch/Python/dynload.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 -N < ../../../patch/Python/ssize-t-max.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 -N < ../../../patch/Python/static-_sqlite3.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 < ../../../patch/Python/xcompile.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 < ../../../patch/Python/setuppath.patch
	# Configure and build iPhone library
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && ./configure CC="$(IPHONE_ARMV7_CC)" LD="$(IPHONE_ARMV7_LD)" CFLAGS="$(IPHONE_ARMV7_CFLAGS) -I../../../dist/ffi.framework/Headers" LDFLAGS="$(IPHONE_ARMV7_LDFLAGS) -L../../../dist/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --host=armv7-apple-darwin --prefix=$(PROJECTDIR)/build/python/ios-armv7 --without-doc-strings
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 < ../../../patch/Python/ctypes_duplicate.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && patch -p1 < ../../../patch/Python/pyconfig.patch
	mkdir -p build/python/ios-armv7
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && cp ../host/python.exe hostpython
	cd build/Python-$(PYTHON_VERSION)/ios-armv7 && make altbininstall libinstall inclinstall libainstall HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes
	# Relocate and rename the libpython binary
	cd build/python/ios-armv7/lib && mv libpython$(basename $(PYTHON_VERSION)).a ../Python
	# Clean up build directory
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && rm config/libpython$(basename $(PYTHON_VERSION)).a config/python.o config/config.c.in config/makesetup
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *test* lib* wsgiref bsddb curses idlelib hotshot
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.pyc' | xargs rm
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.py' | xargs rm
	cd build/python/ios-armv7/lib && rm -rf pkgconfig
	# Pack libraries into .zip file
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && mv config ..
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && mv site-packages ..
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && zip -r ../python27.zip *
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && mv ../config .
	cd build/python/ios-armv7/lib/python$(basename $(PYTHON_VERSION)) && mv ../site-packages .
	# Move all headers except for pyconfig.h into a Headers directory
	mkdir -p build/python/ios-armv7/Headers
	cd build/python/ios-armv7/Headers && mv ../include/python$(basename $(PYTHON_VERSION))/* .
	cd build/python/ios-armv7/Headers && mv pyconfig.h ../include/python$(basename $(PYTHON_VERSION))


build/python/ios-armv7s/Python: build build/Python-$(PYTHON_VERSION)/host/python.exe
	# Unpack sources
	tar zxf downloads/Python-$(PYTHON_VERSION).tgz
	mkdir -p build/Python-$(PYTHON_VERSION)
	mv Python-$(PYTHON_VERSION) build/Python-$(PYTHON_VERSION)/ios-armv7s
	# Apply extra patches for iPhone build
	cp patch/Python/ModulesSetup build/Python-$(PYTHON_VERSION)/ios-armv7s/Modules/Setup.local
	cat patch/Python/ModulesSetup.mobile >> build/Python-$(PYTHON_VERSION)/ios-armv7s/Modules/Setup.local
	cp patch/Python/_scproxy.py build/Python-$(PYTHON_VERSION)/ios-armv7s/Lib/_scproxy.py
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 -N < ../../../patch/Python/dynload.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 -N < ../../../patch/Python/ssize-t-max.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 -N < ../../../patch/Python/static-_sqlite3.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 < ../../../patch/Python/xcompile.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 < ../../../patch/Python/setuppath.patch
	# Configure and build iPhone library
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && ./configure CC="$(IPHONE_ARMV7_CC)" LD="$(IPHONE_ARMV7S_LD)" CFLAGS="$(IPHONE_ARMV7S_CFLAGS) -I../../../dist/ffi.framework/Headers" LDFLAGS="$(IPHONE_ARMV7S_LDFLAGS) -L../../../dist/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --host=armv7s-apple-darwin --prefix=$(PROJECTDIR)/build/python/ios-armv7s --without-doc-strings
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 < ../../../patch/Python/ctypes_duplicate.patch
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && patch -p1 < ../../../patch/Python/pyconfig.patch
	mkdir -p build/python/ios-armv7s
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && cp ../host/python.exe hostpython
	cd build/Python-$(PYTHON_VERSION)/ios-armv7s && make altbininstall libinstall inclinstall libainstall HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes
	# Relocate and rename the libpython binary
	cd build/python/ios-armv7s/lib && mv libpython$(basename $(PYTHON_VERSION)).a ../Python
	# Clean up build directory
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && rm config/libpython$(basename $(PYTHON_VERSION)).a config/python.o config/config.c.in config/makesetup
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *test* lib* wsgiref bsddb curses idlelib hotshot
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.pyc' | xargs rm
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && find . -iname '*.py' | xargs rm
	cd build/python/ios-armv7s/lib && rm -rf pkgconfig
	# Pack libraries into .zip file
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && mv config ..
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && mv site-packages ..
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && zip -r ../python27.zip *
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && rm -rf *
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && mv ../config .
	cd build/python/ios-armv7s/lib/python$(basename $(PYTHON_VERSION)) && mv ../site-packages .
	# Move all headers except for pyconfig.h into a Headers directory
	mkdir -p build/python/ios-armv7s/Headers
	cd build/python/ios-armv7s/Headers && mv ../include/python$(basename $(PYTHON_VERSION))/* .
	cd build/python/ios-armv7s/Headers && mv pyconfig.h ../include/python$(basename $(PYTHON_VERSION))


dist/Python.framework/Python: build/python/ios-simulator/Python build/python/ios-armv7/Python build/python/ios-armv7s/Python build/rubicon-objc-$(RUBICON_VERSION)
	# Create the framework directory from the compiled resrouces
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/
	cd dist/Python.framework/Versions && ln -fs $(basename $(PYTHON_VERSION)) Current
	# Copy the headers from the simulator build
	cp -r build/python/ios-simulator/Headers dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers
	cd dist/Python.framework && ln -fs Versions/Current/Headers
	# Copy the standard library from the simulator build
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources
	cp -r build/python/ios-simulator/lib dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources
	cd dist/Python.framework && ln -fs Versions/Current/Resources
	# Copy the pyconfig headers from the builds, and install the fat header.
	mkdir -p dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/include/python$(basename $(PYTHON_VERSION))
	cp build/python/ios-simulator/include/python$(basename $(PYTHON_VERSION))/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/include/python$(basename $(PYTHON_VERSION))/pyconfig-simulator.h
	cp build/python/ios-armv7/include/python$(basename $(PYTHON_VERSION))/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/include/python$(basename $(PYTHON_VERSION))/pyconfig-armv7.h
	cp patch/Python/pyconfig.h dist/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources/include/python$(basename $(PYTHON_VERSION))/
	# Install Rubicon into site packages.
	cd build && cp -r rubicon-objc-$(RUBICON_VERSION)/rubicon ../dist/Python.framework/Resources/lib/python$(basename $(PYTHON_VERSION))/site-packages/
	# Build a fat library with all targets included.
	xcrun lipo -create -output dist/Python.framework/Versions/Current/Python build/python/ios-simulator/Python build/python/ios-armv7/Python build/python/ios-armv7s/Python
	cd dist/Python.framework && ln -fs Versions/Current/Python


Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz: dist/ffi.framework/ffi dist/Python.framework/Python
	cd dist && tar zcvf ../Python-$(PYTHON_VERSION)-iOS-support.b$(BUILD_NUMBER).tar.gz ffi.framework Python.framework


env:
	# PYTHON_VERSION $(PYTHON_VERSION)
	# FFI_VERSION $(FFI_VERSION)
	# OSX_SDK_ROOT $(OSX_SDK_ROOT)

	# IPHONE_ARMV7_SDK_ROOT $(IPHONE_ARMV7_SDK_ROOT)
	# IPHONE_ARMV7_CC $(IPHONE_ARMV7_CC)
	# IPHONE_ARMV7_LD $(IPHONE_ARMV7_LD)
	# IPHONE_ARMV7_CFLAGS $(IPHONE_ARMV7_CFLAGS)
	# IPHONE_ARMV7_LDFLAGS $(IPHONE_ARMV7_LDFLAGS)

	# IPHONE_ARMV7S_SDK_ROOT $(IPHONE_ARMV7S_SDK_ROOT)
	# IPHONE_ARMV7S_CC $(IPHONE_ARMV7S_CC)
	# IPHONE_ARMV7S_LD $(IPHONE_ARMV7S_LD)
	# IPHONE_ARMV7S_CFLAGS $(IPHONE_ARMV7S_CFLAGS)
	# IPHONE_ARMV7S_LDFLAGS $(IPHONE_ARMV7S_LDFLAGS)

	# IPHONE_SIMULATOR_SDK_ROOT $(IPHONE_SIMULATOR_SDK_ROOT)
	# IPHONE_SIMULATOR_CC $(IPHONE_SIMULATOR_CC)
	# IPHONE_SIMULATOR_LD $(IPHONE_SIMULATOR_LD)
	# IPHONE_SIMULATOR_CFLAGS $(IPHONE_SIMULATOR_CFLAGS)
	# IPHONE_SIMULATOR_LDFLAGS $(IPHONE_SIMULATOR_LDFLAGS)
