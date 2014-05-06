Python.framework
================

This is a meta-package for building a version of Python that can be embedded
into an iOS project. It works by downloading, patching, and *then* building
a static libPython.a, and packaging it in iOS Framework format.

Quickstart
----------

Download/clone this repository, and then in the root directory, run:

    $ make

This should:

1. Download the original source packages
2. Patch them as required for iOS compatibility
3. Build the packages as iOS frameworks.

The build products will be in the `build` directory. You'll need to add
all these frameworks (not just Python.framework) to your project.

Acknowledgements
----------------

This work draws on the groundwork provided by `Kivy's iOS packaging tools.`_

The approach to framework packaging is drawn from `Jeff Verkoeyen`_, and
`Ernesto García's`_ tutorials.

.. _Kivy's iOS packaging tools.: https://github.com/kivy/kivy-ios

.. _Jeff Verkoeyen: https://github.com/jverkoey/iOS-Framework
.. _Ernesto García's: http://www.raywenderlich.com/41377/creating-a-static-library-in-ios-tutorial
