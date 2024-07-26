Python Apple Support
====================

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

**This branch builds a packaged version of Python 3.13.0**.
Other Python versions are available by cloning other branches of the main
repository:

* `Python 3.9 <https://github.com/beeware/Python-Apple-support/tree/3.9>`__
* `Python 3.10 <https://github.com/beeware/Python-Apple-support/tree/3.10>`__
* `Python 3.11 <https://github.com/beeware/Python-Apple-support/tree/3.11>`__
* `Python 3.12 <https://github.com/beeware/Python-Apple-support/tree/3.12>`__
* `Python 3.13 <https://github.com/beeware/Python-Apple-support/tree/3.13>`__

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them as frameworks that can be
incorporated into an XCode project. The binary modules in the Python standard
library are distributed as binaries that can be dynamically loaded at runtime.

The macOS package is a re-bundling of the official macOS binary, modified so that
it is relocatable, with the IDLE, Tkinter and turtle packages removed.

The iOS, tvOS and watchOS packages compiled by this project use the official
`PEP 730 <https://peps.python.org/pep-0730/>`__ code that is part of Python 3.13
to provide iOS support; the relevant patches have been backported to 3.9-3.12.
Additional patches have been applied to add tvOS and watchOS support.

The binaries support x86_64 and arm64 for macOS; arm64 for iOS and appleTV
devices; and arm64_32 for watchOS devices. It also supports device simulators on
both x86_64 and M1 hardware. This should enable the code to run on:

* macOS 11 (Big Sur) or later, on:
    * MacBook (including MacBooks using Apple Silicon)
    * iMac (including iMacs using Apple Silicon)
    * Mac Mini (including Apple Silicon Mac minis)
    * Mac Studio (all models)
    * Mac Pro (all models)
* iOS 13.0 or later, on:
    * iPhone (6s or later)
    * iPad (5th gen or later)
    * iPad Air (all models)
    * iPad Mini (2 or later)
    * iPad Pro (all models)
    * iPod Touch (7th gen or later)
* tvOS 12.0 or later, on:
    * Apple TV (4th gen or later)
* watchOS 4.0 or later, on:
    * Apple Watch (4th gen or later)

Quickstart
----------

The easist way to use these packages is by creating a project with `Briefcase
<https://github.com/beeware/briefcase>`__. Briefcase will download pre-compiled
versions of these support packages, and add them to an Xcode project (or
pre-build stub application, in the case of macOS).

Pre-built versions of the frameworks can be downloaded from the `Github releases page
<https://github.com/beeware/Python-Apple-support/releases>`__ and added to your project.

Alternatively, to build the frameworks on your own, download/clone this
repository, and then in the root directory, and run:

* ``make`` (or ``make all``) to build everything.
* ``make macOS`` to build everything for macOS.
* ``make iOS`` to build everything for iOS.
* ``make tvOS`` to build everything for tvOS.
* ``make watchOS`` to build everything for watchOS.

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the packages as Xcode-compatible XCFrameworks.

The resulting support packages will be packaged as a ``.tar.gz`` file
in the ``dist`` folder.

Each support package contains:

* ``VERSIONS``, a text file describing the specific versions of code used to build the
  support package;
* ``platform-site``, a folder that contains site customization scripts that can be used
  to make your local Python install look like it is an on-device install for each of the
  underlying target architectures supported by the platform. This is needed because when
  you run ``pip`` you'll be on a macOS machine with a specific architecture; if ``pip``
  tries to install a binary package, it will install a macOS binary wheel (which won't
  work on iOS/tvOS/watchOS). However, if you add the ``platform-site`` folder to your
  ``PYTHONPATH`` when invoking pip, the site customization will make your Python install
  return ``platform`` and ``sysconfig`` responses consistent with on-device behavior,
  which will cause ``pip`` to install platform-appropriate packages.
* ``Python.xcframework``, a multi-architecture build of the Python runtime library

On iOS/tvOS/watchOS, the ``Python.xcframework`` contains a
slice for each supported ABI (device and simulator). The folder containing the
slice can also be used as a ``PYTHONHOME``, as it contains a ``bin``, ``include``
and ``lib`` directory.

The ``bin`` folder does not contain Python executables (as they can't be
invoked). However, it *does* contain shell aliases for the compilers that are
needed to build packages. This is required because Xcode uses the ``xcrun``
alias to dynamically generate the name of binaries, but a lot of C tooling
expects that ``CC`` will not contain spaces.

For a detailed instructions on using the support package in your own project,
see the `usage guide <./USAGE.md>`__

Building binary wheels
----------------------

This project packages the Python standard library, but does not address building
binary wheels. Binary wheels for macOS can be obtained from PyPI. `Mobile Forge
<https://github.com/beeware/mobile-forge>`__ is a project that provides the
tooling to build build binary wheels for iOS (and potentially for tvOS and
watchOS, although that hasn't been tested).

Historical support
------------------

The following versions were supported in the past, but are no longer
maintained:

* `Python 2.7 <https://github.com/beeware/Python-Apple-support/tree/2.7>`__ (EOL January 2020)
* `Python 3.4 <https://github.com/beeware/Python-Apple-support/tree/3.4>`__ (EOL March 2019)
* `Python 3.5 <https://github.com/beeware/Python-Apple-support/tree/3.5>`__ (EOL February 2021)
* `Python 3.6 <https://github.com/beeware/Python-Apple-support/tree/3.6>`__ (EOL December 2021)
* `Python 3.7 <https://github.com/beeware/Python-Apple-support/tree/3.7>`__ (EOL September 2022)
* `Python 3.8 <https://github.com/beeware/Python-Apple-support/tree/3.8>`__ (EOL October 2024)
