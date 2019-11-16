Python Apple Support
====================

**This repository branch builds a packaged version of Python 3.6.9**.
Other Python versions are available by cloning other branches of the main
repository.

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them as static libraries that can be
incorporated into an XCode project.

The binaries support x86_64 for macOS; arm64 for iOS and appleTV devices;
and armv7k for watchOS. This should enable the code to run on:

* MacBook
* iMac
* Mac Pro
* iPhone (5s or later)
* iPad (5th gen or later)
* iPad Air (all models)
* iPad Mini (2 or later)
* iPad Pro (all models)
* iPod Touch (6th gen or later)
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

Binary packages
---------------

These tools are also able to compile the following packages that have binary
components:

* `numpy <patch/numpy/README.rst>`__

These binary components are not compiled by default. However, the build
infrastructure of this project can compile them on request. You can run::

    make <name of package>

to build a specific package; or, to build all supported packages::

    make app_packages

For details on how to add these binary packages to your project, see the
package-specific documentation linked above.


.. _for macOS: https://briefcase-support.s3-us-west-2.amazonaws.com/python/3.6/macOS/Python-3.6-macOS-support.b8.tar.gz
.. _for iOS: https://briefcase-support.s3-us-west-2.amazonaws.com/python/3.6/iOS/Python-3.6-iOS-support.b8.tar.gz
.. _for tvOS: https://briefcase-support.s3-us-west-2.amazonaws.com/python/3.6/tvOS/Python-3.6-tvOS-support.b8.tar.gz
.. _for watchOS: https://briefcase-support.s3-us-west-2.amazonaws.com/python/3.6/watchOS/Python-3.6-watchOS-support.b8.tar.gz
