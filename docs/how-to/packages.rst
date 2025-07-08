==========================
Installing Python Packages
==========================

Each slice of an iOS/tvOS/watchOS/visionOS XCframework contains a
``platform-config`` folder with a subfolder for each supported architecture in
that slice. These subfolders can be used to make a macOS Python environment
behave as if it were on an iOS/tvOS/watchOS/visionOS device. This works in one
of two ways:

1. **A sitecustomize.py script**. If the ``platform-config`` subfolder is on
   your ``PYTHONPATH`` when a Python interpreter is started, a site
   customization will be applied that patches methods in ``sys``, ``sysconfig``
   and ``platform`` that are used to identify the system.

2. **A make_cross_venv.py script**. If you call ``make_cross_venv.py``,
   providing the location of a virtual environment, the script will add some
   files to the ``site-packages`` folder of that environment that will
   automatically apply the same set of patches as the ``sitecustomize.py``
   script whenever the environment is activated, without any need to modify
   ``PYTHONPATH``. If you use ``build`` to create an isolated PEP 517
   environment to build a wheel, these patches will also be applied to the
   isolated build environment that is created.

Using one of these two methods, you should be able to use the ``--target``
option of ``pip install`` to install your package to the appropriate location
in your Xcode project for third-party code.

Building binary wheels
----------------------

This project packages the Python standard library, but does not address building
binary wheels. Binary wheels for macOS can be obtained from PyPI. `Mobile Forge
<https://github.com/beeware/mobile-forge>`__ is a project that provides the
tooling to build build binary wheels for iOS (and potentially for tvOS, watchOS,
and visionOS, although that hasn't been tested).