import platform


arch = platform.machine()
if arch == 'arm64':
    from _sysconfigdata__tvos_appletvos_arm64 import *
else:
    raise RuntimeError("Unknown tvOS architecture.")
