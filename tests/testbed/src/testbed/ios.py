from rubicon.objc import ObjCClass

from .utils import assert_


UIResponder = ObjCClass('UIResponder')

# iOS apps need an AppDelegate or they crash
class PythonAppDelegate(UIResponder):
    pass


def test_subprocess():
    "Subprocesses should raise exceptions"
    import subprocess

    try:
        subprocess.call(['uname', '-a'])
        raise AssertionError('Subprocesses should not be possible')
    except RuntimeError as e:
        assert_(str(e) == "Subprocesses are not supported on ios")