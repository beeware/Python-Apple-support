######################################################################
# iOS App main loop
#
# The main loop itself is a no-op; however we need a PythonAppDelegate
# to satisfy the app stub.
#######################################################################
from rubicon.objc import ObjCClass

UIResponder = ObjCClass("UIResponder")


class PythonAppDelegate(UIResponder):
    pass


def main_loop():
    print("Python app launched")
