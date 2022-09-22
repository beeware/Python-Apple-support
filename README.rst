Python Apple Support
====================

**This repository branch builds a packaged version of Python 3.10.7**.
Other Python versions are available by cloning other branches of the main
repository.

This is a meta-package for building a version of Python that can be embedded
into a macOS, iOS, tvOS or watchOS project.

It works by downloading, patching, and building a fat binary of Python and
selected pre-requisites, and packaging them as static libraries that can be
incorporated into an XCode project. The binary modules in the Python standard
library are statically compiled, but are distribted as ``.so`` objects that
can be dynamically loaded at runtime.

It exposes *almost* all the modules in the Python standard library except for:
    * dbm.gnu
    * tkinter
    * readline
    * nis (Deprecated by PEP594)
    * ossaudiodev (Deprecated by PEP594)
    * spwd (Deprecated by PEP594)

The following standard library modules are available on macOS, but not the other
Apple platforms:
    * curses
    * grp
    * multiprocessing
    * posixshmem
    * posixsubprocess
    * syslog

The binaries support x86_64 and arm64 for macOS; arm64 for iOS and appleTV
devices; and arm64_32 for watchOS. It also supports device simulators on both
x86_64 and M1 hardware. This should enable the code to run on:

* macOS 10.15 (Catalina) or later, on:
    * MacBook (including MacBooks using Apple Silicon)
    * iMac (including iMacs using Apple Silicon)
    * Mac Mini (including M1 Apple Silicon Mac minis)
    * Mac Studio (all models)
    * Mac Pro (all models)
* iOS 12.0 or later, on:
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

The easist way to use these packages is by creating a project with `Briefcase
<https://github.com/beeware/briefcase>`__. Briefcase will download pre-compiled
versions of these support packages, and add them to an XCode project (or
pre-build stub application, in the case of macOS).

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

The resulting support packages will be packaged as a ``.tar.gz`` file
in the ``dist`` folder.

Each support package contains:

* ``VERSIONS``, a text file describing the specific versions of code used to
  build the support package;
* ``Python.xcframework``, a multi-architecture build of libPython3.10.a
* ``python-stdlib``, the code and binary modules comprising the Python standard
  library. On iOS, tvOS and watchOS, there are 2 copies of every binary module -
  one for physical devices, and one for the simulator. The simulator binaries
  are "fat", containing code for both x86_64 and arm64.

Non-macOS platforms also contain a ``platform-site`` folder. This contains a
site customization script that can be used to make your local Python install
look like it is an on-device install. This is needed because when you run
``pip`` you'll be on a macOS machine; if ``pip`` tries to install a binary
package, it will install a macOS binary wheel (which won't work on
iOS/tvOS/watchOS). However, if you add the ``platform-site`` folder to your
``PYTHONPATH`` when invoking pip, the site customization will make your Python
install return ``platform`` and ``sysconfig`` responses consistent with
on-device behavior, which will cause ``pip`` to install platform-appropriate
packages.

To add a support package to your own Xcode project:

1. Drag ``Python.xcframework`` and ``python-stdlib`` into your Xcode project
   tree.
2. Ensure that these two objects are added to any targets that need to use
   them;
3. Add a custom build phase to purge any binary modules for the platform you are
   *not* targetting; and
4. Add a custom build phase to sign any of the binary modules in your app.
5. Add CPython API code to your app to create an instance of the Python
   interpreter.

For examples of the scripts needed for steps 3 and 4, and the code needed for
step 5, compare with a project generated with Briefcase.

On macOS, you must also either:
1. Enable the "Disable Library Validation" entitlement (found on the "Signing
   & Capabilities" tab in XCode); or
2. Sign your app with a Development or Distribution certificate. This will
   require a paid Apple Developer subscription.

It is not possible to use an ad-hoc signing certificate with the "Disable
Library Validation" entitlement disabled.

On iOS/tvOS/watchOS, you can use the default developer certificate for deploying
to a device simulator. However, to deploy to a physical device (including your
own), you will require a Development or Distribution certificate, which requires
a paid Apple Developer subscription.

Building binary wheels
----------------------

When building binary wheels, you may need to use the libraries built by this
project as inputs (e.g., the `cffi` module uses `libffi`). To support this, this
project is able to package these dependencies as "wheels" that can be added to
the `server/pypi/dist` directory of the [binary dependency builder
project](https://github.com/freakboy3742/chaquopy).

To build these wheels, run:

* `make wheels` to make all wheels for all mobile platforms
* `make wheels-iOS` to build all the iOS wheels
* `make wheels-tvOS` to build all the tvOS wheels
* `make wheels-watchOS` to build all the watchOS wheels

.. _for macOS: https://briefcase-support.org/python?platform=macOS&version=3.10
.. _for iOS: https://briefcase-support.org/python?platform=iOS&version=3.10
.. _for tvOS: https://briefcase-support.org/python?platform=tvOS&version=3.10
.. _for watchOS: https://briefcase-support.org/python?platform=watchOS&version=3.10
