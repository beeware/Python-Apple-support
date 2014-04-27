PROJECTDIR=$(shell pwd)

# iOS Build variables.
SDKDESCRIPTION=$(shell xcodebuild -showsdks | fgrep "iphoneos" | tail -n 1)
SDKVER=$(word 2, $(SDKDESCRIPTION))
DEVROOT=$(shell xcode-select -print-path)/Platforms/iPhoneOS.platform/Developer
IOSSDKROOT=$(DEVROOT)/SDKs/iPhoneOS$(SDKVER).sdk

OSX_SDK_ROOT=$(shell xcrun --sdk macosx --show-sdk-path)

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=2.7.1
FFI_VERSION=3.0.13

# ARM build flags
ARM_CC=$(shell xcrun -find -sdk iphoneos clang)
ARM_AR=$(shell xcrun -find -sdk iphoneos ar)
ARM_LD=$(shell xcrun -find -sdk iphoneos ld)

ARM_CFLAGS=-arch armv7 -pipe -no-cpp-precomp -isysroot $(IOSSDKROOT) -miphoneos-version-min=$(SDKVER)
ARM_LDFLAGS=-arch armv7 -isysroot $(IOSSDKROOT) -miphoneos-version-min=$(SDKVER)


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

# Down original Python source code archive.
downloads/Python-$(PYTHON_VERSION).tar.bz2:
	curl -L https://www.python.org/ftp/python/$(PYTHON_VERSION)/Python-$(PYTHON_VERSION).tar.bz2 > downloads/Python-$(PYTHON_VERSION).tar.bz2

# Unpack Python source archive into src working directory
src/Python-$(PYTHON_VERSION): downloads/Python-$(PYTHON_VERSION).tar.bz2
	tar xvf downloads/Python-$(PYTHON_VERSION).tar.bz2
	mv Python-$(PYTHON_VERSION) src

# Patch Python source with iOS patches
# Produce a dummy "patches-applied" file to mark that this has happened.
src/Python-$(PYTHON_VERSION)/build_simulator: src/Python-$(PYTHON_VERSION)
	# Apply patches
	cp patch/Python/$(PYTHON_VERSION)/ModulesSetup src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cp patch/Python/$(PYTHON_VERSION)/_scproxy.py src/Python-$(PYTHON_VERSION)/Lib/_scproxy.py
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/dynload.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/ssize-t-max.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/static-_sqlite3.patch
	# Configure and make the x86 (simulator) build
	cd src/Python-$(PYTHON_VERSION) && ./configure CC="clang -Qunused-arguments -fcolor-diagnostics" LDFLAGS="-lsqlite3 -L../../build/ffi.framework" CFLAGS="-I../../build/ffi.framework/Headers --sysroot=$(OSX_SDK_ROOT)" --prefix=$(PROJECTDIR)/src/Python-$(PYTHON_VERSION)/build_simulator
	cd src/Python-$(PYTHON_VERSION) && make -j4 python.exe Parser/pgen libpython$(basename $(PYTHON_VERSION)).a install
	# Create the framework directory from the compiled resrouces
	mkdir -p build/Python.framework/Versions/$(basename $(PYTHON_VERSION))/
	cd build/Python.framework/Versions && ln -fs $(basename $(PYTHON_VERSION)) Current
	cp -r src/Python-$(PYTHON_VERSION)/build_simulator/include/python$(basename $(PYTHON_VERSION)) build/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Headers
	cd build/Python.framework && ln -fs Versions/Current/Headers
	cp -r src/Python-$(PYTHON_VERSION)/build_simulator/lib/python$(basename $(PYTHON_VERSION)) build/Python.framework/Versions/$(basename $(PYTHON_VERSION))/Resources
	cd build/Python.framework && ln -fs Versions/Current/Resources
	# Temporarily move the x86 library into the framework dir to protect it from distclean
	mv src/Python-$(PYTHON_VERSION)/libpython$(basename $(PYTHON_VERSION)).a build/Python.framework
	# Clean out all the x86 build data
	cd src/Python-$(PYTHON_VERSION) && make distclean
	# Restore the x86 library
	mv build/Python.framework/libpython$(basename $(PYTHON_VERSION)).a src/Python-$(PYTHON_VERSION)/build_simulator

src/Python-$(PYTHON_VERSION)/build_iphone: src/Python-$(PYTHON_VERSION)/build_simulator
	# Apply extra patches for iOS native build
	cp patch/Python/$(PYTHON_VERSION)/ModulesSetup src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cat patch/Python/$(PYTHON_VERSION)/ModulesSetup.mobile >> src/Python-$(PYTHON_VERSION)/Modules/Setup.local
	cp patch/Python/$(PYTHON_VERSION)/_scproxy.py src/Python-$(PYTHON_VERSION)/Lib/_scproxy.py
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/xcompile.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/setuppath.patch
	# Configure and build iOS library
	cd src/Python-$(PYTHON_VERSION) && ./configure CC="$(ARM_CC)" LD="$(ARM_LD)" CFLAGS="$(ARM_CFLAGS) -I../../build/ffi.framework/Headers" LDFLAGS="$(ARM_LDFLAGS) -L../../build/ffi.framework/ -lsqlite3 -undefined dynamic_lookup" --without-pymalloc --disable-toolbox-glue --host=armv7-apple-darwin --prefix=/python --without-doc-strings
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/ctypes_duplicate.patch
	cd src/Python-$(PYTHON_VERSION) && patch -p1 -N < ../../patch/Python/$(PYTHON_VERSION)/pyconfig.patch
	cd src/Python-$(PYTHON_VERSION) && make -j4 libpython$(basename $(PYTHON_VERSION)).a

build/Python.framework: src/Python-$(PYTHON_VERSION)/build_iphone
	xcrun lipo -create -output build/Python.framework/Versions/Current/libpython.a src/Python-$(PYTHON_VERSION)/build_simulator/libpython$(basename $(PYTHON_VERSION)).a src/Python-$(PYTHON_VERSION)/libpython$(basename $(PYTHON_VERSION)).a
	cd build/Python.framework && ln -fs Versions/Current/libpython.a

env:
	echo "SDKDESCRIPTION" $(SDKDESCRIPTION)
	echo "SDKVER" $(SDKVER)
	echo "DEVROOT" $(DEVROOT)
	echo "IOSSDKROOT" $(IOSSDKROOT)
	echo "OSX_SDK_ROOT" $(OSX_SDK_ROOT)
	echo "PYTHON_VERSION" $(PYTHON_VERSION)
	echo "FFI_VERSION" $(FFI_VERSION)
	echo "ARM_CC" $(ARM_CC)
	echo "ARM_AR" $(ARM_AR)
	echo "ARM_LD" $(ARM_LD)
	echo "ARM_CFLAGS" $(ARM_CFLAGS)
	echo "ARM_LDFLAGS" $(ARM_LDFLAGS)


# build/Python.framework: src/Python-$(PYTHON_VERSION)/hostpython
