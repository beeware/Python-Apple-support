###########################################################################
# NumPy
###########################################################################

NUMPY_VERSION=1.9.1
NUMPY_CONFIG=BLAS=None LAPACK=None ATLAS=None

# Download original numpy source code archive.
downloads/numpy-$(NUMPY_VERSION).tgz:
	mkdir -p downloads
	# if [ ! -e downloads/numpy-$(NUMPY_VERSION).tgz ]; then curl --fail -L https://github.com/numpy/numpy/releases/download/v$(NUMPY_VERSION)/numpy-$(NUMPY_VERSION).tar.gz -o downloads/numpy-$(NUMPY_VERSION).tgz; fi
	if [ ! -e downloads/numpy-$(NUMPY_VERSION).tgz ]; then curl --fail -L https://github.com/numpy/numpy/archive/v$(NUMPY_VERSION).tar.gz -o downloads/numpy-$(NUMPY_VERSION).tgz; fi

define build-numpy-target
NUMPY-CFLAGS-$1=$$(CFLAGS-$2)
NUMPY-CC-$1=xcrun --sdk $$(SDK-$1) clang \
	-arch $$(ARCH-$1) \
	--sysroot=$$(SDK_ROOT-$1) \
	$$(NUMPY_CFLAGS-$1)

build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libpymath.a: build/$2/packages/numpy
	cd build/$2/packages/numpy && \
		CC="$$(NUMPY-CC-$1)" \
		CFLAGS="$$(NUMPY-CFLAGS-$1)" \
		$(NUMPY_CONFIG) \
		_PYTHON_HOST_PLATFORM=$1 \
		$(HOST_PYTHON) setup.py build_ext

build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libnumpy.a: build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libpymath.a
	cd build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER) && \
		xcrun --sdk $$(SDK-$1) ar -q libnumpy.a `find . -name "*.o"`

numpy-$1: build/$2/packages/numpy/build/temp.$1-$(PYTHON_VER)/libnumpy.a

endef

define build-numpy
$$(foreach target,$$(TARGETS-$1),$$(eval $$(call build-numpy-target,$$(target),$1)))

build/$1/packages/numpy: downloads/numpy-$(NUMPY_VERSION).tgz
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

dist/app_packages/numpy: dist/app_packages build/$1/packages/numpy
	cd build/$1/packages/numpy && \
		$(NUMPY_CONFIG) $(HOST_PIP) install --target $(PROJECT_DIR)/dist/app_packages .
	find build/$1/packages/numpy -name "*.so" -exec rm {} \;

numpy-$1: dist/app_packages/numpy

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
numpy: pip $(foreach os,$(OS),numpy-$(os))
