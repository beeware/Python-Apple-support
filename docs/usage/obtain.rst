==========================
Obtaining Support Packages
==========================

Pre-built versions of the frameworks can be downloaded from the `Github releases page
<https://github.com/beeware/Python-Apple-support/releases>`__ and added to your project.

Alternatively, to build the frameworks on your own, download/clone this
repository, and then in the root directory, and run:

* ``make`` (or ``make all``) to build everything.
* ``make macOS`` to build everything for macOS.
* ``make iOS`` to build everything for iOS.
* ``make tvOS`` to build everything for tvOS.
* ``make watchOS`` to build everything for watchOS.
* ``make visionOS`` to build everything for visionOS.

This should:

1. Download the original source packages
2. Patch them as required for compatibility with the selected OS
3. Build the packages as Xcode-compatible XCFrameworks.

The resulting support packages will be packaged as ``.tar.gz`` files
in the ``dist`` folder.

Each support package contains:

* ``VERSIONS``, a text file describing the specific versions of code used to build the
  support package;
* ``Python.xcframework``, a multi-architecture build of the Python runtime library.

On iOS/tvOS/watchOS/visionOS, the ``Python.xcframework`` contains a
slice for each supported ABI (device and simulator). The folder containing the
slice can also be used as a ``PYTHONHOME``, as it contains a ``bin``, ``include``
and ``lib`` directory.

The ``bin`` folder does not contain Python executables (as they can't be
invoked). However, it *does* contain shell aliases for the compilers that are
needed to build packages. This is required because Xcode uses the ``xcrun``
alias to dynamically generate the name of binaries, but a lot of C tooling
expects that ``CC`` will not contain spaces.

iOS and visionOS distributions also contain a copy of the iOS or visionOS
``testbed`` project - an Xcode project that can be used to run test suites of
Python code. See the `CPython documentation on testing packages
<https://docs.python.org/3/using/ios.html#testing-a-python-package>`__ for
details on how to use this testbed.
