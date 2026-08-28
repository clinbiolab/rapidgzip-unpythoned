# AGENTS.md

## Project purpose

This repository provides a standalone, native build and distribution layer for upstream `rapidgzip`.

The upstream source is included as a pinned Git submodule under:

`external/rapidgzip`

The goal is to build and distribute the existing upstream `rapidgzip` CLI without requiring Python or Python packaging infrastructure.

## Core constraints

### External source is read-only

Treat `external/rapidgzip` and all of its nested submodules as immutable upstream source.

Do not:

* edit files under `external/`
* patch upstream source
* copy upstream source into repository-owned files for modification
* generate modified upstream source
* apply `sed`, Perl, Python, or similar source transformations
* add commits or branches inside upstream submodules
* change submodule revisions unless explicitly requested
* run `git submodule update --remote`

The build must consume the pinned upstream source as-is.

If a requested change appears to require modifying upstream source, stop and report the reason instead of modifying it.

### Zero Python outside upstream

Repository-owned code, build logic, tests, packaging, and CI must use zero Python.

Do not add or invoke:

* Python scripts
* `python` or `python3`
* `pip`
* virtual environments
* setuptools
* Python-based build helpers
* Python-based test helpers

Python files that already exist inside upstream submodules are outside this repository's control. Do not modify them and do not rely on them for the build.

### No dependency downloading

Do not add build steps that fetch or install dependencies from the network.

In particular, do not introduce:

* CMake `FetchContent`
* package-manager bootstrap logic
* automatic `git clone`
* automatic submodule updates
* `curl` or `wget` downloads
* package installation commands

Assume the repository has been cloned with:

```sh
git clone --recursive ...
```

and that the pinned submodule tree is already available locally.

If an additional dependency is genuinely required, report it explicitly rather than downloading or installing it automatically.

## Build design

Prefer the smallest possible external build harness.

Whenever practical:

* reuse the existing upstream CLI implementation
* reuse existing upstream native C/C++ code directly
* keep repository-owned C/C++ code minimal
* keep build logic simple and inspectable
* build outside the upstream source directories
* write generated files only to repository-owned build directories
* preserve the behavior of upstream decompression, input handling, output handling, and CLI semantics

Do not reimplement functionality merely to make the build easier.

Do not introduce abstractions, wrappers, compatibility layers, or new dependencies unless they are necessary.

## Portability

Avoid unnecessary platform-specific assumptions.

The intended targets include Linux, macOS, and Windows using ordinary native toolchains.

Platform-specific build logic is acceptable when required, but keep it isolated and minimal.

Do not sacrifice a straightforward native build on one platform merely to force identical implementation details across all platforms.

## Testing

Testing should primarily verify the build and integration boundary rather than revalidate the upstream compression implementation.

Prefer focused tests that establish properties such as:

* the executable builds successfully
* the upstream submodule remains unmodified
* no Python is required or invoked
* basic CLI operation works
* stdin and stdout operation works where supported upstream
* ordinary gzip decompression produces the expected bytes

Do not build a large independent DEFLATE/gzip conformance suite unless explicitly requested.

## Repository hygiene

Keep changes narrow and easy to review.

Do not commit:

* build outputs
* temporary files
* downloaded dependencies
* generated copies of upstream source
* editor or environment-specific files

Before completing work, verify that:

```sh
git status --short
git -C external/rapidgzip status --short
```

show no unintended changes, and that no nested upstream submodule has been modified.

## Working principle

This repository changes how `rapidgzip` is built and distributed, not how `rapidgzip` decompresses data.

When choosing between a clever solution and a smaller, more transparent one, prefer the smaller and more transparent solution.
