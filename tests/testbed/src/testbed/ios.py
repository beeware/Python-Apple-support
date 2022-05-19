from rubicon.objc import ObjCClass

from .utils import assert_


UIResponder = ObjCClass('UIResponder')

# iOS apps need an AppDelegate or they crash
class PythonAppDelegate(UIResponder):
    pass


def test_subprocess():
    "Subprocesses should raise exceptions"
    import errno
    import subprocess

    try:
        subprocess.call(['uname', '-a'])
        raise AssertionError('Subprocesses should not be possible')
    except OSError as e:
        assert_(e.errno == errno.ENOTSUP)
        assert_(str(e) == "[Errno 45] ios does not support processes.")