Python Apple Support
====================

**This repository branch builds a packaged version of Python 3.4.7**.
Other Python versions are available by cloning other branches of the main
repository.

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them as static libraries that can be
incorporated into an XCode project.

The binaries support the ``$(ARCHS_STANDARD)`` set - that is, x86_64 for
macOS; armv7, armv7s and arm64 for iOS devices, arm64 for appleTV devices, and
armv7k for watchOS. This should enable the code to run on:

* MacBook
* iMac
* Mac Pro
* iPhone (4s or later)
* iPad
* iPod Touch (4th gen or later)
* Apple TV (4th gen or later)
* Apple Watch

Quickstart
----------

Pre-built versions of the frameworks can be downloaded `for macOS`_, `for
iOS`_, `for tvOS`_, and `for watchOS`_, and added to your project.

Alternatively, to build the frameworks on your own, download/clone this
repository, and then in the root directory, and run:

* `make` (or `make all`) to build everything.
* `make macOS` to build everything for macOS.
* `make iOS` to build everything for iOS.
* `make tvOS` to build everything for tvOS.
* `make watchOS` to build everything for watchOS.

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the packages as XCode-compatible frameworks.

The build products will be in the `build` directory; the compiled frameworks
will be in the `dist` directory.

.. _for macOS: https://s3-us-west-2.amazonaws.com/pybee-briefcase-support/Python-Apple-support/3.4/macOS/Python-3.4-macOS-support.b4.tar.gz
.. _for iOS: https://s3-us-west-2.amazonaws.com/pybee-briefcase-support/Python-Apple-support/3.4/iOS/Python-3.4-iOS-support.b4.tar.gz
.. _for tvOS: https://s3-us-west-2.amazonaws.com/pybee-briefcase-support/Python-Apple-support/3.4/tvOS/Python-3.4-tvOS-support.b4.tar.gz
.. _for watchOS: https://s3-us-west-2.amazonaws.com/pybee-briefcase-support/Python-Apple-support/3.4/watchOS/Python-3.4-watchOS-support.b4.tar.gz
