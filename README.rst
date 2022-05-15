Python Apple Support
====================

**This repository branch builds a packaged version of Python 3.8.13**.
Other Python versions are available by cloning other branches of the main
repository.

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them as static libraries that can be
incorporated into an XCode project.

It exposed *almost* all the modules in the Python standard library except for:
    * dbm.gnu
    * tkinter
    * readline
    * nis (Deprecated by PEP594)
    * ossaudiodev (Deprecated by PEP594)
    * spwd (Deprecated by PEP594)

The following standard library modules are available on macOS, but not the other
Apple platforms:
    * curses
    * posixshmem

The binaries support x86_64 and arm64 for macOS; arm64 for iOS and appleTV
devices; and arm64_32 for watchOS. It also supports device simulators on both
x86_64 and M1 hardware. This should enable the code to run on:

* macOS 10.15 (Catalina) or later, on:
    * MacBook (including MacBooks using Apple Silicon)
    * iMac (including iMacs using Apple Silicon)
    * Mac Mini (including M1 Apple Silicon Mac minis)
    * Mac Studio (all models)
    * Mac Pro (all models)
* iOS 13.0 or later, on:
    * iPhone (6s or later)
    * iPad (5th gen or later)
    * iPad Air (all models)
    * iPad Mini (2 or later)
    * iPad Pro (all models)
    * iPod Touch (7th gen or later)
* tvOS 9.0 or later, on Apple TV (4th gen or later)
* watchOS 4.0 or later, on Apple Watch (4th gen or later)

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
3. Build the packages as XCode-compatible XCFrameworks.

The build products will be in the `build` directory; the compiled frameworks
will be in the `dist` directory.

.. _for macOS: https://briefcase-support.org/python?platform=macOS&version=3.8
.. _for iOS: https://briefcase-support.org/python?platform=iOS&version=3.8
.. _for tvOS: https://briefcase-support.org/python?platform=tvOS&version=3.8
.. _for watchOS: https://briefcase-support.org/python?platform=watchOS&version=3.8
