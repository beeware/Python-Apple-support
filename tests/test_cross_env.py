import os
import platform
import sys
import sysconfig
from pathlib import Path

import pytest

# To run these tests, the following three environment variables must be set,
# reflecting the cross-platform environment that is in effect.'
PYTHON_CROSS_PLATFORM = os.getenv("PYTHON_CROSS_PLATFORM", "unknown")
PYTHON_CROSS_SLICE = os.getenv("PYTHON_CROSS_SLICE", "unknown")
PYTHON_CROSS_MULTIARCH = os.getenv("PYTHON_CROSS_MULTIARCH", "unknown")

# Determine some file system anchor points for the tests
# Assumes that the tests are run in a virtual environment named
# `cross-venv`,
VENV_PREFIX = Path(__file__).parent.parent / "cross-venv"
default_support_base = f"support/{sys.version_info.major}.{sys.version_info.minor}/{PYTHON_CROSS_PLATFORM}"
SUPPORT_PREFIX = (
    Path(__file__).parent.parent
    / os.getenv("PYTHON_SUPPORT_BASE", default_support_base)
    / "Python.xcframework"
    / PYTHON_CROSS_SLICE
)


###########################################################################
# sys
###########################################################################

def test_sys_platform():
    assert sys.platform == PYTHON_CROSS_PLATFORM.lower()


def test_sys_cross_compiling():
    assert sys.cross_compiling


def test_sys_multiarch():
    assert sys.implementation._multiarch == PYTHON_CROSS_MULTIARCH


def test_sys_base_prefix():
    assert Path(sys.base_prefix) == SUPPORT_PREFIX


def test_sys_base_exec_prefix():
    assert Path(sys.base_exec_prefix) == SUPPORT_PREFIX


###########################################################################
# platform
###########################################################################

def test_platform_system():
    assert platform.system() == PYTHON_CROSS_PLATFORM


###########################################################################
# sysconfig
###########################################################################

def test_sysconfig_get_platform():
    parts = sysconfig.get_platform().split("-", 2)
    assert parts[0] == PYTHON_CROSS_PLATFORM.lower()
    assert parts[2] == PYTHON_CROSS_MULTIARCH


def test_sysconfig_get_sysconfigdata_name():
    parts = sysconfig._get_sysconfigdata_name().split("_", 4)
    assert parts[3] == PYTHON_CROSS_PLATFORM.lower()
    assert parts[4] == PYTHON_CROSS_MULTIARCH


@pytest.mark.parametrize(
    "name, prefix",
    [
        # Paths that should be relative to the support folder
        ("stdlib", SUPPORT_PREFIX),
        ("include", SUPPORT_PREFIX),
        ("platinclude", SUPPORT_PREFIX),
        ("stdlib", SUPPORT_PREFIX),
        # paths that should be relative to the venv
        ("platstdlib", VENV_PREFIX),
        ("purelib", VENV_PREFIX),
        ("platlib", VENV_PREFIX),
        ("scripts", VENV_PREFIX),
        ("data", VENV_PREFIX),
    ]
)
def test_sysconfig_get_paths(name, prefix):
    assert sysconfig.get_paths()[name].startswith(str(prefix))
