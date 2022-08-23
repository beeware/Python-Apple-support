import platform


arch = platform.machine()
if arch == 'arm64':
    from _sysconfigdata__ios_iphoneos_arm64 import *
else:
    raise RuntimeError("Unknown iOS architecture.")
