Python Apple Support Testbed
============================

This is a testbed application that can be used to do basic verification checks
of the Python Apple Support builds.

The app can be deployed with Briefcase. When executed, (using `briefcase run
macOS Xcode` or `briefcase run iOS`) the app will generate output on the console
log that is similar to a unit test suite. If it returns 0 test failures, you can
have some confidence that the support build is functioning as expected.

The default configuration assumes that you have already run `make` in the root
directory of this repository.
