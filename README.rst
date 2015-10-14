This is a fork of https://github.com/pybee/Python-iOS-support/ that contains
Python.framework WIP for tvOS and watchOS.

In the meantime only OpenSSL.framework can be built for tvOS or watchOS::
  make dist/tvOS/OpenSSL.framework

  make dist/watchOS/OpenSSL.framework

Python iOS Support
==================

This is a meta-package for building a version of Python that can be embedded
into an iOS project.

It works by downloading, patching, and building a fat binary OpenSSL and
Python, and packaging them both in iOS Framework format.

The binaries support the ``$(ARCHS_STANDARD)`` set - that is, armv7 and
arm64. This should enable the code to run on:

* iPhone
    - iPhone 4s
    - iPhone 5
    - iPhone 5s
    - iPhone 6
    - iPhone 6 Plus
* iPad
    - iPad 2
    - iPad (3rd gen)
    - iPad (4th gen)
    - iPad Air
    - iPad retina
* iPad Mini
    - iPad Mini (1st gen)
    - iPad Mini (2nd gen)
* iPod Touch
    - iPod Touch (4th gen)
    - iPod Touch (5th gen)

This repository branch builds a packaged version of **Python 3.4.2**.
Other Python versions are available by cloning other branches of the main
repository.

Quickstart
----------

Pre-built versions of the frameworks can be downloaded_, and added to
your iOS project.

Alternatively, to build the frameworks on your own, download/clone this
repository, and then in the root directory, and run:

    $ make

This should:

1. Download the original source packages
2. Patch them as required for iOS compatibility
3. Build the packages as iOS frameworks.

The build products will be in the `build` directory.

.. _downloaded: https://github.com/pybee/Python-iOS-support/releases/download/3.4.2-b2/Python-3.4.2-iOS-support.b2.tar.gz

Acknowledgements
----------------

The approach to framework packaging is drawn from `Jeff Verkoeyen`_, and
`Ernesto García's`_ tutorials.

.. _Jeff Verkoeyen: https://github.com/jverkoey/iOS-Framework
.. _Ernesto García1G's: http://www.raywenderlich.com/41377/creating-a-static-library-in-ios-tutorial
