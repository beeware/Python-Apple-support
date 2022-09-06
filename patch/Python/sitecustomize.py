# A site customization that can be used to trick pip into installing
# packages cross-platform. If the folder containing this file is on
# your PYTHONPATH when you invoke pip, pip will behave as if it were
# running on {{os}}.
import os
import platform
import sys
import sysconfig

# Make platform.system() return "{{os}}"
def custom_system():
    return "{{os}}"

platform.system = custom_system

# Make sysconfig.get_platform() return "{{tag}}"
def custom_get_platform():
    return "{{tag}}"

sysconfig.get_platform = custom_get_platform

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
