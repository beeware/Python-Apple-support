# A site customization that can be used to trick pip into installing
# packages cross-platform. If the folder containing this file is on
# your PYTHONPATH when you invoke pip, pip will behave as if it were
# running on {{os}}.
import distutils.ccompiler
import distutils.unixccompiler
import os
import platform
import sys
import sysconfig
import types

# Make platform.system() return "{{os}}"
def custom_system():
    return "{{os}}"

platform.system = custom_system

# Make sysconfig.get_platform() return "{{tag}}"
def custom_get_platform():
    return "{{tag}}"

sysconfig.get_platform = custom_get_platform

# Make distutils raise errors if you try to use it to build modules.
DISABLED_COMPILER_ERROR = "Cannot compile native modules"

distutils.ccompiler.get_default_compiler = lambda *args, **kwargs: "disabled"
distutils.ccompiler.compiler_class["disabled"] = (
    "disabledcompiler",
    "DisabledCompiler",
    "Compiler disabled ({})".format(DISABLED_COMPILER_ERROR),
)


def disabled_compiler(prefix):
    # No need to give any more advice here: that will come from the higher-level code in pip.
    from distutils.errors import DistutilsPlatformError

    raise DistutilsPlatformError("{}: {}".format(prefix, DISABLED_COMPILER_ERROR))


class DisabledCompiler(distutils.ccompiler.CCompiler):
    compiler_type = "disabled"

    def preprocess(*args, **kwargs):
        disabled_compiler("CCompiler.preprocess")

    def compile(*args, **kwargs):
        disabled_compiler("CCompiler.compile")

    def create_static_lib(*args, **kwargs):
        disabled_compiler("CCompiler.create_static_lib")

    def link(*args, **kwargs):
        disabled_compiler("CCompiler.link")


# To maximize the chance of the build getting as far as actually calling compile(), make
# sure the class has all of the expected attributes.
for name in [
    "src_extensions",
    "obj_extension",
    "static_lib_extension",
    "shared_lib_extension",
    "static_lib_format",
    "shared_lib_format",
    "exe_extension",
]:
    setattr(
        DisabledCompiler, name, getattr(distutils.unixccompiler.UnixCCompiler, name)
    )

DisabledCompiler.executables = {
    name: [DISABLED_COMPILER_ERROR.replace(" ", "_")]
    for name in distutils.unixccompiler.UnixCCompiler.executables
}

disabled_mod = types.ModuleType("distutils.disabledcompiler")
disabled_mod.DisabledCompiler = DisabledCompiler
sys.modules["distutils.disabledcompiler"] = disabled_mod


# Try to disable native builds for packages which don't use the distutils native build
# system at all (e.g. uwsgi), or only use it to wrap an external build script (e.g. pynacl).
for tool in ["ar", "as", "cc", "cxx", "ld"]:
    os.environ[tool.upper()] = DISABLED_COMPILER_ERROR.replace(" ", "_")


# Call the next sitecustomize script if there is one
# (https://nedbatchelder.com/blog/201001/running_code_at_python_startup.html).
del sys.modules["sitecustomize"]
this_dir = os.path.dirname(__file__)
path_index = sys.path.index(this_dir)
del sys.path[path_index]
try:
    import sitecustomize  # noqa: F401
finally:
    sys.path.insert(path_index, this_dir)
