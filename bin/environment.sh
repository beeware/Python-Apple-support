#!/bin/bash

if [ "X$VERBOSE" == "X1" ]; then
	set -x
fi

try () {
	"$@" || exit -1
}

# iOS SDK Environmnent (don't use name "SDKROOT"!!! it will break the compilation)
export SDKVER=`xcodebuild -showsdks | fgrep "iphoneos" | tail -n 1 | awk '{print $2}'`
export DEVROOT=`xcode-select -print-path`/Platforms/iPhoneOS.platform/Developer
export IOSSDKROOT=$DEVROOT/SDKs/iPhoneOS$SDKVER.sdk

# Xcode doesn't include /usr/local/bin
export PATH="$PATH":/usr/local/bin

if [ ! -d $DEVROOT ]; then
	echo "Unable to found the Xcode iPhoneOS.platform"
	echo
	echo "The path is automatically set from 'xcode-select -print-path'"
	echo " + /Platforms/iPhoneOS.platform/Developer"
	echo
	echo "Ensure 'xcode-select -print-path' is set."
	exit 1
fi

# version of packages
export PYTHON_VERSION=2.7.1
export FFI_VERSION=3.0.13

# where the build will be located
export PROJECTROOT="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
export SRCROOT="$PROJECTROOT/src"
export CACHEROOT="$PROJECTROOT/.cache"
export PATCHROOT="$PROJECTROOT/patch"
export BUILDROOT="$PROJECTROOT/build"

# create directories if not found
try mkdir -p $CACHEROOT
try mkdir -p $SRCROOT
try mkdir -p $BUILDROOT
