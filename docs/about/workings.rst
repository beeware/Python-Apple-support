======================
How This Project Works
======================

Python Apple Support works by downloading, patching, and building a fat binary
of Python and selected pre-requisites, and packaging them as frameworks that can be
incorporated into an Xcode project. The binary modules in the Python standard
library are distributed as binaries that can be dynamically loaded at runtime.

The macOS package is a re-bundling of the official macOS binary, modified so that
it is relocatable, with the IDLE, Tkinter and turtle packages removed, and the
App Store compliance patch applied.

The iOS, tvOS, watchOS, and visionOS packages compiled by this project use the
official `PEP 730 <https://peps.python.org/pep-0730/>`__ code that is part of
Python 3.13 to provide iOS support; the relevant patches have been backported
to 3.9-3.12. Additional patches have been applied to add tvOS, watchOS, and
visionOS support.