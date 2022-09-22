#ifdef __arm__
#include "pyconfig-armv7k.h"
#endif

#ifdef __arm64__
#  ifdef __LP64__
#include "pyconfig-arm64.h"
#  else
#include "pyconfig-arm64_32.h"
#  endif
#endif

#ifdef __x86_64__
#include "pyconfig-x86_64.h"
#endif