Python Testbed
==============

A testbed to run the CPython test suite.

The test suite can be run with `Briefcase <https://briefcase.readthedocs.io/>`__:

* **macOS** `briefcase run --test`
* **iOS** `briefcase run iOS --test`

You can also pass in any command line arguments that the Python test suite honors: e.g.,

* **macOS** `briefcase run --test -- -u all,-largefile,-audio,-gui test_builtin`
* **iOS** `briefcase run iOS --test -- -u all,-largefile,-audio,-gui test_builtin`
