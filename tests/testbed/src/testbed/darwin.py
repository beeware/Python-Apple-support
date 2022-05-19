###########################################################################
# macOS specific tests
###########################################################################
import importlib

from .utils import assert_


def test_scproxy():
    "The _scproxy module has been compiled"
    import _scproxy

    _scproxy._get_proxy_settings()


def test_curses():
    "The curses module has been compiled"
    import curses

    try:
        curses.can_change_color()
    except curses.error:
        # We can't invoke curses methods without raising a curses error;
        # but if we get the error, the module works.
        pass


def test_posix_shmem():
    "POSIX shared memory works"
    from multiprocessing import shared_memory

    # FIXME: For now, we can't actually test multiprocessing
    # because it involves invoking a subprocess, and the macOS app
    # shim doesn't support process duplication. The import is
    # enough to test that the _posixshmem C module exists.
    # try:
    #     obj = shared_memory.ShareableList(
    #         ["howdy", b"HoWdY", -273.154, 100, None, True, 42]
    #     )
    #
    #     assert obj[3] == 100
    # finally:
    #     obj.shm.close()
    #     obj.shm.unlink()
    #     del obj


def test_posix_subprocess():
    "Subprocesses can be invoked"
    import subprocess

    result = subprocess.run(["uname", "-s"], capture_output=True)
    assert_(result.stdout == b"Darwin\n")


def test_stdlib_modules():
    "All the macOS-specific stdlib modules exist"
    missing = []
    for module in [
        "_posixshmem",
        "_scproxy",
    ]:
        try:
            importlib.import_module(module)
        except ModuleNotFoundError:
            missing.append(module)

    assert_(len(missing) == 0, msg=f"Missing stdlib modules: {', '.join(str(m) for m in missing)}")
