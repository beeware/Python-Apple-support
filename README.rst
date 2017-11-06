Python Apple Support
====================

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them both in Apple Framework format.

The binaries support the ``$(ARCHS_STANDARD)`` set - that is, x86_64 for
macOS,  armv7 and arm64 for iOS devices, arm64 for appleTV devices, and armv7k
for watchOS. This should enable the code to run on:

* MacBook
* iMac
* Mac Pro
* iPhone (4s or later)
* iPad
* iPod Touch (4th gen or later)
* Apple TV (4th gen or later)
* Apple Watch


The master branch of this repository has no content; there is an
independent branch for each supported version of Python. The following
Python versions are supported:

* `Python 2.7 <https://github.com/pybee/Python-Apple-support/tree/2.7>`__:
* `Python 3.4 <https://github.com/pybee/Python-Apple-support/tree/3.4>`__:
* `Python 3.5 <https://github.com/pybee/Python-Apple-support/tree/3.5>`__:
* `Python 3.6 <https://github.com/pybee/Python-Apple-support/tree/3.6>`__:
.. * `Python 3.7 <https://github.com/pybee/Python-Apple-support/tree/3.7>`__:
