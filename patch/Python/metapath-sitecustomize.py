import os
import re
import sys
from importlib.abc import MetaPathFinder
from importlib.machinery import EXTENSION_SUFFIXES, ExtensionFileLoader
from importlib.util import spec_from_loader
from pathlib import Path

Frameworks_loc = Path(sys.executable).parent / "Frameworks"

filename_extension = [x for x in EXTENSION_SUFFIXES if bool(re.search(r"\.cpython.*dylib", x))][0]


class MyMetaPathFinder(MetaPathFinder):
    def find_spec(self, fullname, path, target=None):
        if path is None or path == "":
            path = [
                os.getcwd(),
            ]  # top level import

        if "." in fullname:
            *parents, name = fullname.split(".")
        else:
            name = fullname

        for entry in path:
            py_file_name = os.path.join(entry, name + ".py")
            if os.path.exists(py_file_name):
                return None

        file_abs_path = os.path.join(Frameworks_loc, name + ".framework", name + filename_extension)
        if os.path.exists(file_abs_path):
            loader = ExtensionFileLoader(fullname, file_abs_path)
            return spec_from_loader(fullname, loader)
        else:
            return None


sys.meta_path.insert(0, MyMetaPathFinder())
