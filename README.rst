Python iOS Support
==================

This is a meta-package for building a version of Python that can be embedded
into an iOS project.

It works by downloading, patching, and building a fat binary static libffi.a
and libPython.a, and packaging them both in iOS Framework format.

The ``site-packages`` has the `Rubicon Objective-C`_ library pre-installed.
This library enables you to have direct access to the iOS system libraries
from within the Python environment.

The binaries support the ``$(ARCHS_STANDARD_32_BIT)`` set - that is, armv7 and
armv7s. This should enable the code to run on:

* iPhone
    - iPhone 3GS,
    - iPhone 4
    - iPhone 4s
    - iPhone 5
    - iPhone 5s
* iPad
    - iPad 2
    - iPad (3rd gen)
    - iPad (4th gen)
    - iPad Air
* iPad Mini
    - iPad Mini (1st gen)
    - iPad Mini (2nd gen)
* iPod Touch
    - iPod Touch (4th gen)
    - iPod Touch (5th gen)

This repository branch builds a packaged version of **Python 2.7.1**.
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

The build products will be in the `build` directory. You'll need to add
**all** these frameworks (not just Python.framework) to your project.

.. _downloaded: https://github.com/pybee/Python-iOS-support/releases/download/2.7.1-b3/Python-2.7.1-iOS-support.b3.tar.gz

Acknowledgements
----------------

This work draws on the groundwork provided by `Kivy's iOS packaging tools.`_

The approach to framework packaging is drawn from `Jeff Verkoeyen`_, and
`Ernesto García's`_ tutorials.

.. _Kivy's iOS packaging tools.: https://github.com/kivy/kivy-ios
.. _Jeff Verkoeyen: https://github.com/jverkoey/iOS-Framework
.. _Ernesto García's: http://www.raywenderlich.com/41377/creating-a-static-library-in-ios-tutorial
.. _Rubicon Objective-C: http://github.com/pybee/rubicon-objc
