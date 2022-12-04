# Usage Guide

A Step-by-Step guide on how to embed a Python interpreter in a MacOS app (The process for an iOS app should be quite similar).
No need to delete the Sandbox (you need it to be able to submit your MacOS App to the App Store).
No need to `Disable Library Validation`.

1. Add PythonKit SPM:
https://github.com/pvieito/PythonKit

2. Download Released framework for the desired Python version (for MacOS platform):
https://github.com/beeware/Python-Apple-support

3. Extract the `python-stdlib` and `Python.xcframework` from the `tag.gz` archive.

4. Copy `python-stdlib` and `Python.xcframework` to the root of the MacOS App, preferably via Xcode.

5. Xcode General -> Frameworks:
	5.1. Should already be there:
		- `Python.xcframework` is set as `Do Not Embed`
		- `PythonKit`
	5.2. Add additional required framework:
		- `SystemConfiguration.framework` set as `Do Not Embed`

6. Xcode `Build Phases`:
	6.1. Verify `Copy Bundle Resources` contains `python-stdlib`.
	6.2. Add bash script to Sign `.so` binaries in `python-stdlib/lib-dynload/`:
	IMPORTANT NOTE: `.so` binaries must be signed with your TeamID, if you need to use `Sign and Run Locally` it will be signed as ad-hoc, and you will need to `Disable Library Validation`.
```bash
set -e
echo "Signing as $EXPANDED_CODE_SIGN_IDENTITY_NAME ($EXPANDED_CODE_SIGN_IDENTITY)"
find "$CODESIGNING_FOLDER_PATH/Contents/Resources/python-stdlib/lib-dynload" -name "*.so" -exec /usr/bin/codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" -o runtime --timestamp=none --preserve-metadata=identifier,entitlements,flags --generate-entitlement-der {} \;
```

7. Create a file called `module.modulemap` with the following code:
```
module Python {
    umbrella header "Python.h"
    export *
    link "Python"
}
```

8. Place the `module.modulemap` file inside the `Python.xcframework/macos-arm64_x86_64/Headers/`.
This will allow us to do `import Python`

9. Init Python at runtime, as early as possible:
```swift
import Python

guard let stdLibPath = Bundle.main.path(forResource: "python-stdlib", ofType: nil) else { return }
guard let libDynloadPath = Bundle.main.path(forResource: "python-stdlib/lib-dynload", ofType: nil) else { return }
setenv("PYTHONHOME", stdLibPath, 1)
setenv("PYTHONPATH", "\(stdLibPath):\(libDynloadPath)", 1)
Py_Initialize()
// we now have a Python interpreter ready to be used
```

10. Run test code:
```swift
import PythonKit

let sys = Python.import("sys")
print("Python Version: \(sys.version_info.major).\(sys.version_info.minor)")
print("Python Encoding: \(sys.getdefaultencoding().upper())")
print("Python Path: \(sys.path)")

_ = Python.import("math") // verifies `lib-dynload` is found and signed successfully
```

11. To integrate 3rd party python code and dependencies, you will need to make sure `PYTHONPATH` contains their paths;
And then you can just do `Python.import(" <SOME LIB> ")`.

You're in business.
