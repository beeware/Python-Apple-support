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

Changes to to support other platforms can be included in a PR for this repo, but
they must also be submitted as a pull request against the `MAJOR.MINOR-patched`
branch on [the `freakboy3742` fork of the CPython
repo](https://github.com/freakboy3742/cpython). This is required to ensure that
any contributed changes can be easily reproduced in future patches as more
changes are made.

Note that the `MAJOR.MINOR-patched` branch of that fork is maintained in the format
of a *patch tree*, which is a branch that has an entirely linear sequence of
commits applied on top of another branch (in the case of the fork, `MAJOR.MINOR`),
each of which adding a new feature. Therefore, bug fixes to the patches applied
*will* be merged, but their changes gets squashed into the commit applying the
feature. Feature additions to the patch will be squashed into a single commit,
and then merged.

This also means that if another contributor on the fork gets a pull request merged
into the fork, you must *rebase*, not merge, your changes on top of the newly pulled
`MAJOR.MINOR-patched` branch, since the "history" of a patch tree branch might
change in a way that is incompatible with merge commits.
