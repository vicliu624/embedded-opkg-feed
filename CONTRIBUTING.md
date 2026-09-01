# Contributing a userland package

[中文](CONTRIBUTING.zh-CN.md) | English (current)

We welcome public userland packages through pull requests: shared libraries,
command-line tools, desktop programs, and device applications. This repository
is not a binary upload site and not a general cross-device RISC-V distribution.

## What a contributor submits

A PR may add or change one directory under `packages/<package-name>/` with:

```text
package.env                 package metadata and supported platforms
build.sh                    optional, reviewed build hook
root/                       package payload after a reproducible build
README.md                   user-facing purpose, license and test instructions
```

For native programs and libraries, `build.sh` must build against the selected
platform's pinned SDK/sysroot and populate `root/`. It must not download
unpinned tools or prebuilt binaries at release time. A normal `application`
package cannot write `/usr/lib`; an audited `shared-library` recipe may ship
only runtime SONAME files there. See [the shared-runtime contract](docs/SHARED_RUNTIMES.md).

## Package metadata

`package.env` must define:

```sh
PACKAGE='your-github-handle-my-app'
VERSION='1.0.0-1'
MAINTAINER='Your Name <you@example.com>'
DESCRIPTION='One-line application description'
SUPPORTED_PLATFORMS='tdvp-k230-r1'
PACKAGE_KIND='application' # or shared-library
PACKAGE_RELEASES='r2'
PACKAGE_DEPENDS=''
```

The packaging script injects the exact ABI dependency. Do not write
`tdvp-platform-abi` manually in `PACKAGE_DEPENDS`.

## Naming and ownership

- First-party names beginning with `tdvp-` are reserved for project maintainers.
- Generic upstream libraries keep their upstream names (for example `sdl2`),
  while community applications use `<github-handle>-<application>`, all lowercase.
- Do not reuse another contributor's prefix or mimic a base-system package.
- A package must include an OSI-compatible license or an explicit redistribution
  grant for every shipped source and binary asset.

## PR rules

Do not change these in a normal package PR:

- `site/` or any generated `.ipk`, `Packages`, `Packages.gz`, or signature;
- `platforms/` ABI manifests;
- `keys/`;
- signing/publishing workflows;
- firmware-owned paths listed in [docs/PLATFORM.md](docs/PLATFORM.md).

The PR template asks for the platform, build inputs, source origin, license,
resource impact, and test results. A maintainer will inspect the payload and
run the package in a matching test image before signing it.

## Local validation

On a Linux host with the matching SDK:

```sh
./scripts/build-all.sh --platform tdvp-k230-r1 --release r7 --output dist
./scripts/verify-feed.sh --platform tdvp-k230-r1 \
  dist/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r2/r7/riscv64
```

The existence of a successful `.ipk` build is not sufficient for acceptance;
the package must also pass its functional test on the declared platform.
