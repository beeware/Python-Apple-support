# iOS Build variables.
SDKVER=$(xcodebuild -showsdks | fgrep "iphoneos" | tail -n 1 | awk '{print $2}')
DEVROOT=$(xcode-select -print-path)/Platforms/iPhoneOS.platform/Developer
IOSSDKROOT=$DEVROOT/SDKs/iPhoneOS$(SDKVER).sdk

# Version of packages that will be compiled by this meta-package
PYTHON_VERSION=2.7.1
FFI_VERSION=3.0.13

all: dirs libffi

download:
	mkdir -p downloads

src:
	mkdir -p src

build:
	mkdir -p build

dirs: download src build

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

# Patch libffi source with iOS patches
# Produce a dummy ".patches-applied" file to mark that this has happened.
src/libffi-$(FFI_VERSION)/.patches-applied: src/libffi-$(FFI_VERSION)
	cd src/libffi-$(FFI_VERSION) && patch -p1 < ../../patch/libffi/$(FFI_VERSION)/ffi-sysv.S.patch
	cd src/libffi-$(FFI_VERSION) && patch -p1 < ../../patch/libffi/$(FFI_VERSION)/project.pbxproj.patch
	touch src/libffi-$(FFI_VERSION)/.patches-applied

# Generate iOS specific source and headers
src/libffi-$(FFI_VERSION)/ios/include/ffi.h: src/libffi-$(FFI_VERSION)/.patches-applied
	cd src/libffi-$(FFI_VERSION) && python generate-ios-source-and-headers.py

# Build the iOS project
src/libffi-$(FFI_VERSION)/build/Release-universal/ffi.framework: src/libffi-$(FFI_VERSION)/ios/include/ffi.h
	cd src/libffi-$(FFI_VERSION) && xcodebuild -project libffi.xcodeproj -target "Framework" -configuration Release -sdk iphoneos$(SDKVER) OTHER_CFLAGS="-no-integrated-as"

# Collate the libffi project
libffi: clean-libffi src/libffi-$(FFI_VERSION)/build/Release-universal/ffi.framework
	cp -a src/libffi-$(FFI_VERSION)/build/Release-universal/ffi.framework build

# Clean all builds
clean:
	rm -rf src build

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads
