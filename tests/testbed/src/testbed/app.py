"""
A testbed for the Apple Support packages.
"""
import platform
import sys
import traceback

from . import common
from . import macos


def discover_tests(module):
    "Discover all the test methods in the given module"
    return [
        (getattr(module, "__name__").split(".")[-1], getattr(module, name))
        for name in dir(module)
        if name.startswith("test_")
    ]


def main():
    # This should start and launch your app!
    print("=" * 80)
    print(f"Python {platform.python_version()} Apple Support verification suite")
    print(f"Running on {platform.platform()}")
    print("=" * 80)
    # Discover the suite
    suite = discover_tests(common)
    if sys.platform == "darwin":
        suite.extend(discover_tests(macos))

    # Run the suite
    failures = 0
    tests = 0
    for sys_platform, test in suite:
        try:
            tests += 1
            # If the test has a docstring, use that text;
            # otherwise, use the test name
            if test.__doc__:
                print(f"{sys_platform}: {test.__doc__}", end="...")
            else:
                print(f"{sys_platform}: {test.__name__}", end="...")
            test()
            print(" ok")
        except Exception as e:
            failures += 1
            print(" FAILED!")
            print("-" * 80)
            traceback.print_exception(e)
            print("-" * 80)

    print("=" * 80)
    print(f"Tests complete; {tests} tests, {failures} failures.")
    sys.exit(int(failures != 0))
