# TDVP Embedded Linux Package Feed

[中文](README.md) | English (current)

This is a **public, distribution-style userland package feed for embedded Linux devices**. It lets a device install tested ABI-matched libraries, command-line tools, desktop programs, and device applications through `opkg`, while building a common runtime library once and sharing it through normal package dependencies.

It is not a “works on every RISC-V device” repository. On embedded systems, the C library, CPU ABI, kernel, and base-system components are often tied together. A package built for the wrong combination may fail to start or damage the system. Every package therefore declares the platforms it supports, and only packages built and checked by maintainers are published.

## Which document should I read?

| I want to… | Start here |
| --- | --- |
| Install software on a device | [Device usage guide](docs/USAGE.md) |
| Submit a program or library | [Contribution guide](CONTRIBUTING.md) |
| Bring a new device/firmware platform to the feed | [Platform guide](docs/PLATFORM.md) |
| Build, sign, and publish a release | [Release guide](docs/RELEASE.md) |
| Repair the device-side opkg and signature support | [Device bootstrap guide](docs/DEVICE_BOOTSTRAP.md) |

## The repository in three sentences

1. **Developers submit userland software or shared-library source and package metadata; maintainers build, test, sign, and publish it.**
2. **GitHub Pages is the public download location; a signed index proves that the published feed came from the maintainers.**
3. **Feed packages must not replace immutable core system components.** libc, the kernel, system services, the boot chain, `opkg` itself, and the KPU driver belong to the firmware, not this feed.

The intended model is the same division of responsibility used by a normal
Linux distribution: the base image is a small, hardware-specific bootstrap and
ABI seed; the feed is the expandable userland catalogue. From r6, **every
dynamic runtime SONAME, plugin, and private runtime helper other than the
dynamic loaders, glibc, `libgcc_s`, and `libstdc++` has exactly one
independently installable IPK owner in the same ABI release.** The audit covers
`/usr/lib`, `/usr/libexec`, `/usr/local/lib`, and `/usr/local/libexec`; the
local locations are audited so that an accidental private shared object cannot
become an undeclared base-image dependency. SDL2, libmGBA, libcurl, libpng,
libjpeg, libutf8proc, GTK3, common CLI tools, desktop applications, and
device-specific applications therefore ship as independent packages with exact
versioned dependencies; leaf applications neither statically bundle libraries
nor borrow a general-purpose runtime from the base image. It is deliberately
not an unbounded binary repository for every RISC-V board: each feed release is
tied to one declared TDVP platform ABI.

## Currently supported platform

The first platform is `tdvp-k230-r1`:

| Item | Current value |
| --- | --- |
| Device SoC | Kendryte K230 |
| Base system | Buildroot 2025.02.1 |
| CPU architecture | 64-bit RISC-V, LP64D |
| C library | glibc 2.33 |
| Kernel baseline | Linux 6.6.36 |
| Platform ABI ID | `tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1` |

Read the [platform guide](docs/PLATFORM.md) for the full compatibility boundary. If your device differs from this baseline, do not install this platform's packages directly; define a separate platform first.

## For device users: when is it safe to install packages?

Only use this feed with the corresponding signed TDVP K230 base-firmware
release. That long-term keyboard-handheld release embeds this feed's public
key, provides the exact `tdvp-platform-abi` marker, and uses its
`tdvp-opkg` wrapper to initialize the keyring and require the signed package
index when an operator actually uses the feed. This is deliberately not a
desktop boot prerequisite. Do not point an older image or another RISC-V
distribution at this URL.

After flashing that bootstrap image and after the signed feed is published, a
normal installation looks like this:

```sh
sudo tdvp-opkg update
sudo tdvp-opkg list
sudo tdvp-opkg install tdvp-gba
tdvp-gba
```

The actual feed URL, public-key installation, and troubleshooting live in the
[device usage guide](docs/USAGE.md). `tdvp-gba` is built from a reviewed,
commit-locked source tree with the exact TDVP SDK; it explicitly depends on
the shared `sdl2`, `sdl2-ttf`, and `libmgba` packages. Those libraries are
built once for the exact RISC-V/TDVP ABI in one feed release. The published r1
package `tdvp-cardputer-zero-gba` remains immutable as a legacy record only.

## For package developers: how do I contribute?

The usual path is:

1. Fork this repository and create a branch.
2. Copy `packages/_template/`, then rename the directory and edit `package.env` for your program or library.
3. Put program runtime files under `root/`. A shared-library recipe may put only audited SONAME files in `/usr/lib`; its headers and build metadata remain in the temporary release staging sysroot and never ship to a device.
4. Build and check the package in your development environment.
5. Open a Pull Request explaining the software, supported platform, dependencies, and how you tested it.

For example:

```sh
TDVP_SDK_ROOT=/path/to/output/host \
TDVP_FEED_BASE_ROOT=/path/to/output/target \
./scripts/build-all.sh --platform tdvp-k230-r1 --release r4 --output dist
./scripts/verify-feed.sh --platform tdvp-k230-r1 \
  dist/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r4/riscv64
```

Submit **reviewable source, build scripts, and package metadata**. Do not submit generated `.ipk` files, `Packages`, `Packages.gz`, signatures, or `site/feed/` content. They are release outputs. The full checklist is in [CONTRIBUTING.md](CONTRIBUTING.md).

## For maintainers: how does a release work?

```text
Developer Pull Request
        ↓
CI validates recipes, source locks, and portable build tooling
        ↓
Maintainer builds and tests with the exact K230 SDK, then signs the index offline
        ↓
GitHub Actions validates the signature and publishes GitHub Pages
        ↓
Devices download and verify through opkg
```

The private key never goes into Git, a Pull Request, or GitHub Pages. A release maintainer signs `Packages.gz` in an offline or controlled environment; the repository contains only the public key. See the [signing guide](docs/SIGNING.md) and [release guide](docs/RELEASE.md) for the exact procedure.

## Naming and safety boundaries

- The `tdvp-` prefix is reserved for packages released by platform maintainers, such as `tdvp-gba`.
- Generic upstream libraries keep their normal package names, such as `sdl2`, `sdl2-ttf`, and `libmgba`; ABI compatibility comes from the platform dependency and `Architecture`, not a TDVP library-name prefix.
- Community applications should use `<github-handle>-<app-name>`, for example `alice-status-panel`, to avoid name collisions.
- A package must declare its supported platforms. The build script adds the platform ABI dependency automatically; it cannot be skipped by hand.
- `application` packages must not write to or replace `/boot`, `/lib`, `/lib64`, `/usr/lib`, `/usr/lib/systemd`, or `/usr/sbin`. Only maintainer-reviewed `shared-library` or `runtime` recipes may ship controlled runtime content; the builder rejects protected-runtime replacement, duplicate SONAMEs, undeclared dynamic dependencies, static/private copies of general libraries, and any non-identical base-image overlay.

## Local development

The repository scripts target a POSIX shell. Windows developers can use WSL. You need at least `bash`, `tar`, `gzip`, `ar`, and `sha256sum`; release signing also needs GnuPG.

```sh
# Inspect the available build and release tools
ls scripts

# Start a new package from the template
cp -a packages/_template packages/<your-package-name>
```

If you see “ABI mismatch”, “system path is forbidden”, or “index signature is invalid”, do not bypass the check. It is usually preventing a package that would not be safe to install. Fix the metadata, base firmware, or signing flow described in the linked guide.

## Repository layout

```text
platforms/    ABI and platform definitions for supported devices
packages/     userland package sources, build metadata, and installed files
scripts/      build, index, verification, signing, and site-staging tools
keys/         public repository signing keys only
docs/         device, platform, bootstrap, signing, and release documentation
site/         static content that GitHub Pages will publish
```

## Licence and contributor responsibilities

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a Pull Request. When adding a third-party application, make sure you have the right to distribute its source, binaries, and dependencies, and state its licence clearly in the PR.
