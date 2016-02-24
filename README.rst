Python iOS Support
==================

This is a meta-package for building a version of Python that can be embedded
into an iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary OpenSSL and
Python, and packaging them both in iOS Framework format.

The binaries support the ``$(ARCHS_STANDARD)`` set - that is, armv7 and
arm64 for iOS devices, arm64 for appleTV devices, and armv7k for watchOS.
This should enable the code to run on:

* iPhone
    - iPhone 4s
    - iPhone 5
    - iPhone 5c
    - iPhone 5s
    - iPhone 6
    - iPhone 6 Plus
    - iPhone 6s
    - iPhone 6s Plus
* iPad Pro
* iPad
    - iPad 2
    - iPad (3rd gen)
    - iPad (4th gen)
    - iPad Air
    - iPad Air 2
    - iPad retina
* iPad Mini
    - iPad Mini (1st gen)
    - iPad Mini 2
    - iPad Mini 3
    - iPad Mini 4
* iPod Touch
    - iPod Touch (4th gen)
    - iPod Touch (5th gen)
    - iPod Touch (6th gen)
* Apple TV
    - 4th gen
* Apple Watch

This repository branch builds a packaged version of **Python 3.5.1**.
Other Python versions are available by cloning other branches of the main
repository.

Quickstart
----------

Pre-built versions of the frameworks can be downloaded `for iOS`_,
`for tvOS`_, and `for watchOS`_, and added to your project.

Alternatively, to build the frameworks on your own, download/clone this
repository, and then in the root directory, and run:

* `make` (or `make all`) to build everything.
* `make iOS` to build everything for iOS.
* `make tvOS` to build everything for tvOS.
* `make watchOS` to build everything for watchOS.

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the packages as XCode-compatible frameworks.

The build products will be in the `build` directory; the compiled frameworks
will be in the `dist` directory.

.. _for iOS: https://github.com/pybee/Python-iOS-support/releases/download/3.4.2-b5/Python-3.4.2-iOS-support.b5.tar.gz
.. _for tvOS: https://github.com/pybee/Python-iOS-support/releases/download/3.4.2-b5/Python-3.4.2-iOS-support.b5.tar.gz
.. _for watchOS: https://github.com/pybee/Python-iOS-support/releases/download/3.4.2-b5/Python-3.4.2-iOS-support.b5.tar.gz

Acknowledgements
----------------

The approach to framework packaging is drawn from `Jeff Verkoeyen`_, and
`Ernesto García's`_ tutorials.

.. _Jeff Verkoeyen: https://github.com/jverkoey/iOS-Framework
.. _Ernesto García's: http://www.raywenderlich.com/41377/creating-a-static-library-in-ios-tutorial
