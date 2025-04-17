# Contributing

BeeWare <3's contributions!

Please be aware that BeeWare operates under a [Code of
Conduct](https://beeware.org/community/behavior/code-of-conduct/).

See [CONTRIBUTING to BeeWare](https://beeware.org/contributing) for general
project contribution guidelines.

Unless a fix is version specific, PRs should genereally be made against the
`main` branch of this repo, targeting the current development version of Python.
Project maintainers will manage the process of backporting changes to older
Python versions.

## Changes to `Python.patch`

Additional handling is required if you need to make modifications to the patch
applied to Python sources (`patch/Python/Python.patch`).

Any iOS or macOS-specific changes should be submitted to the [upstream CPython
repository](https://github.com/python/cpython). macOS and iOS are both
officially supported Python platforms, and the code distributed by this project
for those platforms is unmodified from the official repository.

Changes to to support other platforms can be included in this PR, but they must
also be submitted as a pull request against the `MAJOR.MINOR-patched` branch on
[the `freakboy3742` fork of the CPython
repo](https://github.com/freakboy3742/cpython). This is required to ensure that
any contributed changes can be easily reproduced in future patches as more
changes are made.
