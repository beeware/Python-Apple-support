PROJECTDIR=$(shell pwd)

# iOS Build variables.
OSX_SDK_ROOT=$(shell xcrun --sdk macosx --show-sdk-path)

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=2.7.1
FFI_VERSION=3.0.13

# IPHONE build commands and flags
IPHONE_SDK_ROOT=$(shell xcrun --sdk iphoneos --show-sdk-path)
IPHONE_CC=$(shell xcrun -find -sdk iphoneos clang)
IPHONE_LD=$(shell xcrun -find -sdk iphoneos ld)
IPHONE_CFLAGS=-arch armv7 -pipe -no-cpp-precomp -isysroot $(IPHONE_SDK_ROOT) -miphoneos-version-min=4.0
IPHONE_LDFLAGS=-arch armv7 -isysroot $(IPHONE_SDK_ROOT) -miphoneos-version-min=4.0

# IPHONESIMULATOR build commands and flags
IPHONESIMULATOR_SDK_ROOT=$(shell xcrun --sdk iphonesimulator --show-sdk-path)
IPHONESIMULATOR_CC=$(shell xcrun -find -sdk iphonesimulator clang)
IPHONESIMULATOR_LD=$(shell xcrun -find -sdk iphonesimulator ld)
IPHONESIMULATOR_CFLAGS=-arch i386 -pipe -no-cpp-precomp -isysroot $(IPHONESIMULATOR_SDK_ROOT) -miphoneos-version-min=4.0
IPHONESIMULATOR_LDFLAGS=-arch i386 -isysroot $(IPHONESIMULATOR_SDK_ROOT) -miphoneos-version-min=4.0


all: working-dirs build/ffi.framework build/Python.framework

# Clean all builds
clean:
	rm -rf src build

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

###########################################################################
# Working directories
###########################################################################

download:
	mkdir -p downloads

src:
	mkdir -p src

build:
	mkdir -p build

working-dirs: download src build

###########################################################################
# libFFI
###########################################################################

# Clean the libffi project
clean-libffi:
	rm -rf src/libffi-$(FFI_VERSION)
	rm -rf build/ffi.framework

# Down original libffi source code archive.
downloads/libffi-$(FFI_VERSION).tar.gz:
	curl -L ftp://sourceware.org/pub/libffi/libffi-$(FFI_VERSION).tar.gz > downloads/libffi-$(FFI_VERSION).tar.gz

# Unpack libffi source archive into src working directory
src/libffi-$(FFI_VERSION): downloads/libffi-$(FFI_VERSION).tar.gz
	tar xvf downloads/libffi-$(FFI_VERSION).tar.gz
	mv libffi-$(FFI_VERSION) src

# Patch and build the framework
build/ffi.framework: src/libffi-$(FFI_VERSION)
	cd src/libffi-$(FFI_VERSION) && patch -p1 -N < ../../patch/libffi/$(FFI_VERSION)/ffi-sysv.S.patch
	cd src/libffi-$(FFI_VERSION) && patch -p1 -N < ../../patch/libffi/$(FFI_VERSION)/project.pbxproj.patch
	cd src/libffi-$(FFI_VERSION) && python generate-ios-source-and-headers.py
	cd src/libffi-$(FFI_VERSION) && xcodebuild -project libffi.xcodeproj -target "Framework" -configuration Release -sdk iphoneos$(SDKVER) OTHER_CFLAGS="-no-integrated-as"
	cp -a src/libffi-$(FFI_VERSION)/build/Release-universal/ffi.framework build

###########################################################################
# Python
###########################################################################

# Clean the Python project
clean-Python:
	rm -rf src/Python-$(PYTHON_VERSION)
	rm -rf build/Python.framework
	rm -rf build/python

# Down original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tar.bz2:
	curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tar.bz2 > downloads/Python-$(PYTHON_VERSION).tar.bz2

# Unpack Python source archive into src working directory
src/Python-$(PYTHON_VERSION): downloads/Python-$(PYTHON_VERSION).tar.bz2
	tar xvf downloads/Python-$(PYTHON_VERSION).tar.bz2
	mv Python-$(PYTHON_VERSION) src

# Patch Python source with iOS patches
# Produce a dummy "patches-applied" file to mark that this has happened.
src/Python-$(PYTHON_VERSION)/build: src/Python-$(PYTHON_VERSION)
	# Apply patches
	cp patch/Python/$(PYTHON_VERSION)/ModulesSetup src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cp patch/Python/$(PYTHON_VERSION)/_scproxy.py src/Python-$(PYTHON_VERSION)/Lib/_scproxy.py
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/dynload.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/ssize-t-max.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/static-_sqlite3.patch
	# Configure and make the local build, providing compiled resources.
	# cd src/Python-$(PYTHON_VERSION) && ./configure CC="clang -Qunused-arguments -fcolor-diagnostics" LDFLAGS="-lsqlite3 -L../../build/ffi.framework" CFLAGS="-I../../build/ffi.framework/Headers --sysroot=$(OSX_SDK_ROOT)" --prefix=$(PROJECTDIR)/src/Python-$(PYTHON_VERSION)/build
	cd src/Python-$(PYTHON_VERSION) && ./configure CC="clang -Qunused-arguments -fcolor-diagnostics" LDFLAGS="-lsqlite3" CFLAGS="--sysroot=$(OSX_SDK_ROOT)" --prefix=$(PROJECTDIR)/src/Python-$(PYTHON_VERSION)/build
	cd src/Python-$(PYTHON_VERSION) && make -j4 python.exe Parser/pgen
	cd src/Python-$(PYTHON_VERSION) && mv python.exe hostpython
	cd src/Python-$(PYTHON_VERSION) && mv Parser/pgen Parser/hostpgen
	# # Clean out all the build data
	cd src/Python-$(PYTHON_VERSION) && make distclean

build/python/ios-simulator/Python: src/Python-$(PYTHON_VERSION)/build
	# Apply extra patches for iOS simulator build
	cp patch/Python/$(PYTHON_VERSION)/ModulesSetup src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cat patch/Python/$(PYTHON_VERSION)/ModulesSetup.mobile >> src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cp patch/Python/$(PYTHON_VERSION)/_scproxy.py src/Python-$(PYTHON_VERSION)/Lib/_scproxy.py
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/xcompile.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/setuppath.patch
	# Configure and build Simulator library
	cd src/Python-$(PYTHON_VERSION) && ./configure CC="$(IPHONESIMULATOR_CC)" LD="$(IPHONESIMULATOR_LD)" CFLAGS="$(IPHONESIMULATOR_CFLAGS) -I../../build/ffi.framework/Headers" LDFLAGS="$(IPHONESIMULATOR_LDFLAGS) -L../../build/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --prefix=/python --without-doc-strings
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/ctypes_duplicate.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/pyconfig.patch
	mkdir -p build/python/ios-simulator
	cd src/Python-$(PYTHON_VERSION) && make altbininstall libinstall inclinstall libainstall HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes prefix="../../build/python/ios-simulator"
	# Relocate and rename the libpython binary
	cd build/python/ios-simulator/lib && mv libpython$(basename $(PYTHON_VERSION)).a ../Python
	# Clean out all the build data
	cd src/Python-$(PYTHON_VERSION) && make distclean
	# Reverse the source patches.
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/xcompile.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/setuppath.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/ctypes_duplicate.patch
	# cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/pyconfig.patch
	# Clean up build directory
	cd build/python/ios-simulator/lib/python2.7 && rm config/libpython2.7.a config/python.o config/config.c.in config/makesetup
	cd build/python/ios-simulator/lib/python2.7 && rm -rf *test* lib* wsgiref bsddb curses idlelib hotshot
	cd build/python/ios-simulator/lib/python2.7 && find . -iname '*.pyc' | xargs rm
	cd build/python/ios-simulator/lib/python2.7 && find . -iname '*.py' | xargs rm
	cd build/python/ios-simulator/lib && rm -rf pkgconfig
	# Pack libraries into .zip file
	cd build/python/ios-simulator/lib/python2.7 && mv config ..
	cd build/python/ios-simulator/lib/python2.7 && mv site-packages ..
	cd build/python/ios-simulator/lib/python2.7 && zip -r ../python27.zip *
	cd build/python/ios-simulator/lib/python2.7 && rm -rf *
	cd build/python/ios-simulator/lib/python2.7 && mv ../config .
	cd build/python/ios-simulator/lib/python2.7 && mv ../site-packages .
	# Move all headers except for pyconfig.h into a Headers directory
	mkdir -p build/python/ios-simulator/Headers
	cd build/python/ios-simulator/Headers && mv ../include/python2.7/* .
	cd build/python/ios-simulator/Headers && mv pyconfig.h ../include/python2.7


build/python/ios-armv7/Python: src/Python-$(PYTHON_VERSION)/build
	# Apply extra patches for iPhone build
	cp patch/Python/$(PYTHON_VERSION)/ModulesSetup src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cat patch/Python/$(PYTHON_VERSION)/ModulesSetup.mobile >> src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cp patch/Python/$(PYTHON_VERSION)/_scproxy.py src/Python-$(PYTHON_VERSION)/Lib/_scproxy.py
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/xcompile.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/setuppath.patch
	# Configure and build iPhone library
	cd src/Python-$(PYTHON_VERSION) && ./configure CC="$(IPHONE_CC)" LD="$(IPHONE_LD)" CFLAGS="$(IPHONE_CFLAGS) -I../../build/ffi.framework/Headers" LDFLAGS="$(IPHONE_LDFLAGS) -L../../build/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --host=armv7-apple-darwin --prefix=/python --without-doc-strings
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/ctypes_duplicate.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 < ../../patch/Python/$(PYTHON_VERSION)/pyconfig.patch
	mkdir -p build/python/ios-armv7
	cd src/Python-$(PYTHON_VERSION) && make altbininstall libinstall inclinstall libainstall HOSTPYTHON=./hostpython CROSS_COMPILE_TARGET=yes prefix="../../build/python/ios-armv7"
	# Relocate and rename the libpython binary
	cd build/python/ios-armv7/lib && mv libpython$(basename $(PYTHON_VERSION)).a ../Python
	# Clean out all the build data
	cd src/Python-$(PYTHON_VERSION) && make distclean
	# Reverse the source patches.
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/xcompile.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/setuppath.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/ctypes_duplicate.patch
	# cd src/Python-$(PYTHON_VERSION) && patch -p1 -R < ../../patch/Python/$(PYTHON_VERSION)/pyconfig.patch
	# Clean up build directory
	cd build/python/ios-armv7/lib/python2.7 && rm config/libpython2.7.a config/python.o config/config.c.in config/makesetup
	cd build/python/ios-armv7/lib/python2.7 && rm -rf *test* lib* wsgiref bsddb curses idlelib hotshot
	cd build/python/ios-armv7/lib/python2.7 && find . -iname '*.pyc' | xargs rm
	cd build/python/ios-armv7/lib/python2.7 && find . -iname '*.py' | xargs rm
	cd build/python/ios-armv7/lib && rm -rf pkgconfig
	# Pack libraries into .zip file
	cd build/python/ios-armv7/lib/python2.7 && mv config ..
	cd build/python/ios-armv7/lib/python2.7 && mv site-packages ..
	cd build/python/ios-armv7/lib/python2.7 && zip -r ../python27.zip *
	cd build/python/ios-armv7/lib/python2.7 && rm -rf *
	cd build/python/ios-armv7/lib/python2.7 && mv ../config .
	cd build/python/ios-armv7/lib/python2.7 && mv ../site-packages .
	# Move all headers except for pyconfig.h into a Headers directory
	mkdir -p build/python/ios-simulator/Headers
	cd build/python/ios-simulator/Headers && mv ../include/python2.7/* .
	cd build/python/ios-simulator/Headers && mv pyconfig.h ../include/python2.7

build/Python.framework: build/python/ios-simulator/Python build/python/ios-armv7/Python
	# Create the framework directory from the compiled resrouces
	mkdir -p build/Python.framework/Versions/$(basename $(PYTHON_VERSION))/
	cd build/Python.framework/Versions && ln -fs $(basename $(PYTHON_VERSION)) Current
	# Copy the headers from the simulator
	cp -r build/python/ios-simulator/Headers build/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers
	cd build/Python.framework && ln -fs Versions/Current/Headers
	# Build a fat library with all targets included.
	xcrun lipo -create -output build/Python.framework/Versions/Current/Python build/python/ios-simulator/Python build/python/ios-armv7/Python
	cd build/Python.framework && ln -fs Versions/Current/Python
	# Clean up simulator dir
	rm -rf build/python/ios-simulator/bin
	rm -rf build/python/ios-simulator/Python
	# Clean up armv7 dir
	rm -rf build/python/ios-armv7/bin
	rm -rf build/python/ios-armv7/Python

env:
	# PYTHON_VERSION $(PYTHON_VERSION)
	# FFI_VERSION $(FFI_VERSION)
	# OSX_SDK_ROOT $(OSX_SDK_ROOT)
	# IPHONE_SDK_ROOT $(IPHONE_SDK_ROOT)
	# IPHONE_CC $(IPHONE_CC)
	# IPHONE_LD $(IPHONE_LD)
	# IPHONE_CFLAGS $(IPHONE_CFLAGS)
	# IPHONE_LDFLAGS $(IPHONE_LDFLAGS)
	# IPHONESIMULATOR_SDK_ROOT $(IPHONESIMULATOR_SDK_ROOT)
	# IPHONESIMULATOR_CC $(IPHONESIMULATOR_CC)
	# IPHONESIMULATOR_LD $(IPHONESIMULATOR_LD)
	# IPHONESIMULATOR_CFLAGS $(IPHONESIMULATOR_CFLAGS)
	# IPHONESIMULATOR_LDFLAGS $(IPHONESIMULATOR_LDFLAGS)
