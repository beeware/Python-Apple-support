###########################################################################
# Testing utilities
###########################################################################


def assert_(condition, msg=None):
    if not condition:
        raise AssertionError(msg if msg else "Test assertion failed")
