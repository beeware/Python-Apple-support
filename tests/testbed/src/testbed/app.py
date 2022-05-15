"""
A testbed for the Apple Support packages.
"""
import importlib
import platform
import sys
import traceback

from . import common


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
    # Discover the common test suite
    suite = discover_tests(common)

    # Discover the platform-specific tests
    try:
        module = importlib.import_module(f".{sys.platform}", "testbed")
        suite.extend(discover_tests(module))
    except ModuleNotFoundError:
        print(f"No platform-specific tests for {sys.platform}")

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
        except Exception:
            failures += 1
            print(" FAILED!")
            print("-" * 80)
            traceback.print_exc()
            print("-" * 80)

    print("=" * 80)
    print(f"Tests complete; {tests} tests, {failures} failures.")
    sys.exit(failures)
