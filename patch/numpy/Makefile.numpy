###########################################################################
# NumPy
###########################################################################

NUMPY_VERSION=1.16.3
NUMPY_CONFIG=BLAS=None LAPACK=None ATLAS=None

# Download original numpy source code archive.
downloads/numpy-$(NUMPY_VERSION).tgz:
	mkdir -p downloads
	if [ ! -e downloads/numpy-$(NUMPY_VERSION).tgz ]; then curl --fail -L https://github.com/numpy/numpy/releases/download/v$(NUMPY_VERSION)/numpy-$(NUMPY_VERSION).tar.gz -o downloads/numpy-$(NUMPY_VERSION).tgz; fi

define build-numpy-target
NUMPY-CFLAGS-$1=$$(CFLAGS-$1)
NUMPY-CC-$1=xcrun --sdk $$(SDK-$1) clang \
	-arch $$(ARCH-$1) \
	--sysroot $$(SDK_ROOT-$1)
NUMPY-LDSHARED-iphonesimulator.x86_64=xcrun --sdk 'iphonesimulator' clang \
	-arch x86_64 -Wall \
	--sysroot $$(SDK_ROOT-$1) -v -r -fembed-bitcode
NUMPY-LDLIB-iphonesimulator.x86_64=$(abspath build/iOS/)
NUMPY-LDSHARED-iphoneos.arm64=xcrun --sdk 'iphoneos' clang \
	-arch arm64 -Wall \
	--sysroot $$(SDK_ROOT-$1) -v -r -fembed-bitcode
NUMPY-LDLIB-iphoneos.arm64=$(abspath build/iOS/)


build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libpymath.a: build/$2/packages/numpy
	cd build/$2/packages/numpy && \
		CC="$$(NUMPY-CC-$1)" \
		CFLAGS="$$(NUMPY-CFLAGS-$1)" \
		BASECFLAGS="" \
		LDSHARED="$$(NUMPY-LDSHARED-$1)" \
		LDLIB="$$(NUMPY-LDLIB-$1)" \
		$(NUMPY_CONFIG) \
		_PYTHON_HOST_PLATFORM=$1 \
		$(HOST_PYTHON) setup.py --verbose --no-user-cfg  build_ext

build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libnumpy.a: build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libpymath.a
	cd build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER) && \
		CC="$$(NUMPY-CC-$1)" \
		CFLAGS="$$(NUMPY-CFLAGS-$1)" \
		BASECFLAGS="" \
		LDSHARED="$$(NUMPY-LDSHARED-$1)" \
		LDLIB="$$(NUMPY-LDLIB-$1)" \
		$(NUMPY_CONFIG) \
		_PYTHON_HOST_PLATFORM=$1 \
		xcrun --sdk $$(SDK-$1) ar -q libnumpy.a `find . -name "*.o"`

numpy-$1: build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libnumpy.a

endef

define build-numpy
$$(foreach target,$$(TARGETS-$1),$$(eval $$(call build-numpy-target,$$(target),$1)))

build/$1/packages/numpy: pip downloads/numpy-$(NUMPY_VERSION).tgz
	# Unpack numpy sources
	mkdir -p build/$1/packages/numpy
	tar zxf downloads/numpy-$(NUMPY_VERSION).tgz --strip-components 1 -C build/$1/packages/numpy
	# Apply patch
	cd build/$1/packages/numpy && patch -p1 -i $(PROJECT_DIR)/patch/numpy/numpy.patch
	# Install requirements for compiling Numpy
	$(HOST_PIP) install cython

ifeq ($1,macOS)
# Use the macOS build as a reference installation
# Just install the source as-is into the dist/app_packages directory
# Then clean out all the binary artefacts

dist/app_packages/numpy: pip dist/app_packages build/macOS/packages/numpy
	cd build/macOS/packages/numpy && \
		$(NUMPY_CONFIG) $(HOST_PIP) install --target $(PROJECT_DIR)/dist/app_packages .
	find build/macOS/packages/numpy -name "*.so" -exec rm {} \;

numpy-macOS: dist/app_packages/numpy

else
# For all other platforms, run the numpy build for each target architecture

dist/$1/libnumpy.a: $(foreach target,$(TARGETS-$1),numpy-$(target))
	mkdir -p dist/$1
	xcrun lipo -create -output dist/$1/libnpymath.a $(foreach target,$(TARGETS-$1),build/$1/packages/numpy/build/temp.$(target)-$(PYTHON_VER)/libnpymath.a)
	xcrun lipo -create -output dist/$1/libnpysort.a $(foreach target,$(TARGETS-$1),build/$1/packages/numpy/build/temp.$(target)-$(PYTHON_VER)/libnpysort.a)
	xcrun lipo -create -output dist/$1/libnumpy.a $(foreach target,$(TARGETS-$1),build/$1/packages/numpy/build/temp.$(target)-$(PYTHON_VER)/libnumpy.a)

numpy-$1: dist/$1/libnumpy.a

endif
endef

# Call build-numpy for each packaged OS target
$(foreach os,$(OS),$(eval $(call build-numpy,$(os))))

# Main entry point
numpy: $(foreach os,$(OS),numpy-$(os))
