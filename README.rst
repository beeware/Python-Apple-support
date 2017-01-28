Python Apple Support
====================

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them both in Apple Framework format.

The binaries support the ``$(ARCHS_STANDARD)`` set - that is, x86_64 for
macOS,  armv7 and arm64 for iOS devices, arm64 for appleTV devices, and armv7k
for watchOS. This should enable the code to run on:

* MacBook (including Pro & Air)
* iMac
* Mac Pro
* iPhone
    - iPhone 4s
    - iPhone 5
    - iPhone 5c
    - iPhone 5s
    - iPhone 6
    - iPhone 6 Plus
    - iPhone 6s
    - iPhone 6s Plus
    - iPhone 7
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


The master branch of this repository has no content; there is an
independent branch for each supported version of Python. The following
Python versions are supported:

* `Python 2.7.13 <https://github.com/pybee/Python-Apple-support/tree/2.7>`__:

  * `macOS <https://github.com/pybee/Python-Apple-support/releases/download/2.7-b2/Python-2.7-macOS-support.b2.tar.gz>`__
  * `iOS <https://github.com/pybee/Python-Apple-support/releases/download/2.7-b2/Python-2.7-iOS-support.b2.tar.gz>`__
  * `tvOS <https://github.com/pybee/Python-Apple-support/releases/download/2.7-b2/Python-2.7-tvOS-support.b2.tar.gz>`__
  * `watchOS <https://github.com/pybee/Python-Apple-support/releases/download/2.7-b2/Python-2.7-watchOS-support.b2.tar.gz>`__

* `Python 3.4.6 <https://github.com/pybee/Python-Apple-support/tree/3.4>`__:

  * `macOS <https://github.com/pybee/Python-Apple-support/releases/download/3.4-b2/Python-3.4-macOS-support.b2.tar.gz>`__
  * `iOS <https://github.com/pybee/Python-Apple-support/releases/download/3.4-b2/Python-3.4-iOS-support.b2.tar.gz>`__
  * `tvOS <https://github.com/pybee/Python-Apple-support/releases/download/3.4-b2/Python-3.4-tvOS-support.b2.tar.gz>`__
  * `watchOS <https://github.com/pybee/Python-Apple-support/releases/download/3.4-b2/Python-3.4-watchOS-support.b2.tar.gz>`__

* `Python 3.5.3 <https://github.com/pybee/Python-Apple-support/tree/3.5>`__:

  * `macOS <https://github.com/pybee/Python-Apple-support/releases/download/3.5-b3/Python-3.5-macOS-support.b3.tar.gz>`__
  * `iOS <https://github.com/pybee/Python-Apple-support/releases/download/3.5-b3/Python-3.5-iOS-support.b3.tar.gz>`__
  * `tvOS <https://github.com/pybee/Python-Apple-support/releases/download/3.5-b3/Python-3.5-tvOS-support.b3.tar.gz>`__
  * `watchOS <https://github.com/pybee/Python-Apple-support/releases/download/3.5-b3/Python-3.5-watchOS-support.b3.tar.gz>`__

