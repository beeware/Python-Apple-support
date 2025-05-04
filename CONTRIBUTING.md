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
of a *patch tree*, which is a branch that consists of an entirely linear sequence of
commits applied on top of another branch (in the case of the fork, `MAJOR.MINOR`),
each of which adds a significant new feature. Therefore, a bug fix for an existing commit
in the patch tree *will* be merged when appropriate, but its changes will get combined
with that existing commit that adds the feature. A feature addition PR will be squashed
into a single, new commit, and then put on top of the patch tree.

This also means that if another contributor gets a pull request merged into
`MAJOR.MINOR-patched`, you must *rebase* your changes on top of the updated
`MAJOR.MINOR-patched` branch, as opposed to *merging* `MAJOR.MINOR-patched` into your
branch, since the "history" of a patch tree is likely to change in a way that is
incompatible with merge commits.
