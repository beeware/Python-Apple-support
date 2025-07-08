# Usage Guide

## The easy way

The easist way to use these packages is by creating a project with
[Briefcase](https://github.com/beeware/briefcase). Briefcase will download
pre-compiled versions of these support packages, and add them to an Xcode project
(or pre-build stub application, in the case of macOS).

## The manual way

**NOTE** Briefcase usage is the officially supported approach for using this
support package. If you are experiencing diffculties, one approach for debugging
is to generate a "Hello World" project with Briefcase, and compare the project that
Briefcase has generated with your own project.

The Python support package *can* be manually added to any Xcode project;
however, you'll need to perform some steps manually (essentially reproducing
what Briefcase is doing). The steps required are documented in the CPython usage
guides:

* [macOS](https://docs.python.org/3/using/mac.html)
* [iOS](https://docs.python.org/3/using/ios.html#adding-python-to-an-ios-project)

For tvOS, watchOS, and visionOS, you should be able to broadly follow the instructions
in the iOS guide, changing some platform names in the first script. The testbed projects
generated on iOS and visionOS may be used as rough references as well.

### Using Objective C

Once you've added the Python XCframework to your project, you'll need to
initialize the Python runtime in your Objective C code (This is step 10 of the
iOS guide linked above). This initialization should generally be done as early
as possible in the application's lifecycle, but definitely needs to be done
before you invoke Python code.

As a *bare minimum*, you can do the following:

1. Import the Python C API headers:
   ```objc
   #include <Python/Python.h>
   ```

2. Initialize the Python interpreter:
   ```objc
   NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
   NSString *pythonHome = [NSString stringWithFormat:@"%@/python", resourcePath, nil];
   NSString *appPath = [NSString stringWithFormat:@"%@/app", resourcePath, nil];

   setenv("PYTHONHOME", [pythonHome UTF8String], 1);
   setenv("PYTHONPATH", [appPath UTF8String], 1);

   Py_Initialize();

   // we now have a Python interpreter ready to be used
   ```

Again - this is the *bare minimum* initialization. In practice, you will likely
need to configure other aspects of the Python interpreter using the
`PyPreConfig`  and `PyConfig` mechanisms. Consult the [Python documentation on
interpreter configuration](https://docs.python.org/3/c-api/init_config.html) for
more details on the configuration options that are available. You may find the
[bootstrap mainline code used by
Briefcase](https://github.com/beeware/briefcase-iOS-Xcode-template/blob/main/%7B%7B%20cookiecutter.format%20%7D%7D/%7B%7B%20cookiecutter.class_name%20%7D%7D/main.m)
a helpful point of comparison.

### Using Swift

If you want to use Swift instead of Objective C, the bare minimum initialization
code will look something like this:

1. Import the Python framework:
   ```swift
   import Python
   ```

2. Initialize the Python interpreter:
   ```swift
   guard let pythonHome = Bundle.main.path(forResource: "python", ofType: nil) else { return }
   let appPath = Bundle.main.path(forResource: "app", ofType: nil)

   setenv("PYTHONHOME", pythonHome, 1)
   setenv("PYTHONPATH", appPath, 1)
   Py_Initialize()
   // we now have a Python interpreter ready to be used
   ```

   Again, references to a specific Python version should reflect the version of
   Python you are using; and you will likely need to use `PyPreConfig` and
   `PreConfig` APIs.

## Accessing the Python runtime

There are 2 ways to access the Python runtime in your project code.

### Embedded C API

You can use the [Python Embedded C
API](https://docs.python.org/3/extending/embedding.html) to invoke Python code
and interact with Python objects. This is a raw C API that is accesible to both
Objective C and Swift.

### PythonKit

If you're using Swift, an alternate approach is to use
[PythonKit](https://github.com/pvieito/PythonKit). PythonKit is a package that
provides a Swift API to running Python code.

To use PythonKit in your project, add the Python Apple Support package to your
project and instantiate a Python interpreter as described above; then add
PythonKit to your project using the Swift Package manager (see the [PythonKit
documentation](https://github.com/pvieito/PythonKit) for details).

Once you've done this, you can import PythonKit:
```swift
import PythonKit
```
and use the PythonKit Swift API to interact with Python code:
```swift
let sys = Python.import("sys")
print("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
print("Python Encoding: \(sys.getdefaultencoding().upper())")
print("Python Path: \(sys.path)")
```
