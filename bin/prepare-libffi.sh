#!/bin/bash

echo "Building libffi ============================="

. $(dirname $0)/environment.sh

if [ ! -f $CACHEROOT/libffi-$FFI_VERSION.tar.gz ]; then
    try curl -L ftp://sourceware.org/pub/libffi/libffi-$FFI_VERSION.tar.gz > $CACHEROOT/libffi-$FFI_VERSION.tar.gz
fi

# Clear out any existing build
if [ -d $SRCROOT/libffi-$FFI_VERSION ]; then
    try rm -rf $SRCROOT/libffi-$FFI_VERSION
    try tar xvf $CACHEROOT/libffi-$FFI_VERSION.tar.gz
    try mv libffi-$FFI_VERSION $SRCROOT
    try rm -rf build/ffi.framework
fi

# lib not found, compile it
pushd $SRCROOT/libffi-$FFI_VERSION

try patch -p1 -N < $PATCHROOT/libffi/$FFI_VERSION/ffi-sysv.S.patch
try patch -p1 -N < $PATCHROOT/libffi/$FFI_VERSION/project.pbxproj.patch

# Generate iOS code expected by project.
python generate-ios-source-and-headers.py

# Build the framework
xcodebuild -project libffi.xcodeproj -target "Framework" -configuration Release -sdk iphoneos$SDKVER OTHER_CFLAGS="-no-integrated-as"

# Copy the built framework into the build directory
try cp -a build/Release-universal/ffi.framework $BUILDROOT

popd
