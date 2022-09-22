import os


# os.uname().machine is the host CPU architecture on the simulator
arch = os.uname().machine
if arch == 'x86_64':
    from _sysconfigdata__ios_iphonesimulator_x86_64 import *
elif arch == 'arm64':
    from _sysconfigdata__ios_iphonesimulator_arm64 import *
else:
    raise RuntimeError("Unknown iOS simulator architecture.")
