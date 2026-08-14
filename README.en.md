# Embedded Application Feed

[中文](README.md) | English (current)

This is a **public application feed for embedded Linux devices**. Its job is simple: let a device install tested application packages through `opkg`, while making sure every package matches that device's ABI.

It is not a “works on every RISC-V device” repository. On embedded systems, the C library, CPU ABI, kernel, and base-system components are often tied together. A package built for the wrong combination may fail to start or damage the system. Every package therefore declares the platforms it supports, and only packages built and checked by maintainers are published.

## Which document should I read?

| I want to… | Start here |
| --- | --- |
| Install an application on a device | [Device usage guide](docs/USAGE.md) |
| Submit my own application | [Contribution guide](CONTRIBUTING.md) |
| Bring a new device/firmware platform to the feed | [Platform guide](docs/PLATFORM.md) |
| Build, sign, and publish a release | [Release guide](docs/RELEASE.md) |
| Repair the device-side opkg and signature support | [Device bootstrap guide](docs/DEVICE_BOOTSTRAP.md) |

## The repository in three sentences

1. **Developers submit application source and package metadata; maintainers build, test, sign, and publish it.**
2. **GitHub Pages is the public download location; a signed index proves that the published feed came from the maintainers.**
3. **Application packages must not replace core system components.** libc, the kernel, system services, the networking stack, `opkg` itself, and the KPU driver belong to the firmware, not this feed.

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

## For device users: can I install packages right away?

**Not on a newly provisioned target yet.** The current target device has incomplete `opkg` configuration and no usable index-signature verifier. First rebuild and flash the corresponding base firmware by following the [device bootstrap guide](docs/DEVICE_BOOTSTRAP.md). Only then can the device safely trust the public feed.

After the bootstrap is complete, a normal installation looks like this:

```sh
opkg update
opkg list
opkg install tdvp-hello
tdvp-hello
```

The actual feed URL, public-key installation, and troubleshooting live in the [device usage guide](docs/USAGE.md). `tdvp-hello` is a simple end-to-end test package, not a required application.

## For application developers: how do I contribute?

The usual path is:

1. Fork this repository and create a branch.
2. Copy `packages/_template/`, then rename the directory and edit `package.env` for your application.
3. Put the files your application needs under `root/`; they will be installed at the same locations beneath the device root filesystem.
4. Build and check the package in your development environment.
5. Open a Pull Request explaining the application, supported platform, dependencies, and how you tested it.

For example:

```sh
./scripts/build-all.sh --platform tdvp-k230-r1 --output dist
./scripts/verify-feed.sh --platform tdvp-k230-r1 \
  dist/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/riscv64
```

Submit **reviewable source, build scripts, and package metadata**. Do not submit generated `.ipk` files, `Packages`, `Packages.gz`, signatures, or `site/feed/` content. They are release outputs. The full checklist is in [CONTRIBUTING.md](CONTRIBUTING.md).

## For maintainers: how does a release work?

```text
Developer Pull Request
        ↓
CI builds and validates candidate packages
        ↓
Maintainer tests in a controlled environment and signs the index offline
        ↓
GitHub Actions validates the signature and publishes GitHub Pages
        ↓
Devices download and verify through opkg
```

The private key never goes into Git, a Pull Request, or GitHub Pages. A release maintainer signs `Packages.gz` in an offline or controlled environment; the repository contains only the public key. See the [signing guide](docs/SIGNING.md) and [release guide](docs/RELEASE.md) for the exact procedure.

## Naming and safety boundaries

- The `tdvp-` prefix is reserved for packages released by platform maintainers, such as `tdvp-hello`.
- Community packages should use `<github-handle>-<app-name>`, for example `alice-status-panel`, to avoid name collisions.
- A package must declare its supported platforms. The build script adds the platform ABI dependency automatically; it cannot be skipped by hand.
- Application packages must not write to or replace `/boot`, `/lib`, `/lib64`, `/usr/lib`, `/usr/lib/systemd`, or `/usr/sbin`. This keeps public applications from accidentally replacing the system base.

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
packages/     application sources, build metadata, and installed files
scripts/      build, index, verification, signing, and site-staging tools
keys/         public repository signing keys only
docs/         device, platform, bootstrap, signing, and release documentation
site/         static content that GitHub Pages will publish
```

## Licence and contributor responsibilities

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a Pull Request. When adding a third-party application, make sure you have the right to distribute its source, binaries, and dependencies, and state its licence clearly in the PR.
