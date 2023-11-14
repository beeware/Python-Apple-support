import os
import sys
from macholib.MachOStandalone import MachOStandalone


if __name__ == "__main__":
    MachOStandalone(
        sys.argv[1],
        os.path.abspath(f"{sys.argv[1]}/")
    ).run(contents="@rpath/")
