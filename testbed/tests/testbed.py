import os
from pathlib import Path

from test.libregrtest import main
import faulthandler


def run_tests():
    project_path = Path(__file__).parent.parent
    os.chdir(project_path)

    # Install a dummy traceback handler.
    # faulthandler tries to use fileno on sys.stderr, which doesn't work on iOS
    # because sys.stderr has been redirected to NSLog.
    def dump_traceback_later(*args, **kwargs):
        pass

    faulthandler.dump_traceback_later = dump_traceback_later

    try:
        main()
    except SystemExit as e:
        returncode = e.code
    print(f">>>>>>>>>> EXIT {returncode} <<<<<<<<<<")


if __name__ == "__main__":
    run_tests()
