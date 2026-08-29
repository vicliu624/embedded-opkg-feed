# How to use the public feed

[中文](USAGE.zh-CN.md) | English (current)

## Prerequisites on the device

The target must already have a base firmware that provides all of the
following:

1. a matching `tdvp-platform-abi` marker registered as installed;
2. a valid opkg state database and list directory;
3. a trusted CA bundle and correct time for HTTPS;
4. a tested opkg index-signature verification backend;
5. the embedded public key that verifies this repository's release key.

The signed TDVP K230 r1 long-term base image supplies items 1, 2, 4, and 5.
Its `tdvp-opkg` wrapper initializes the dedicated keyring immediately before
each package-manager operation, so the feed remains outside the boot path. The
remaining operator requirements are a working network connection and valid
time for HTTPS certificate validation. An older image is not an acceptable
substitute; follow
[DEVICE_BOOTSTRAP.md](DEVICE_BOOTSTRAP.md) when producing the base image.

## Configure the TDVP K230 r1 feed

The current base image installs this **single, ABI-specific r2 feed** in
`/etc/opkg/tdvp-feed.conf`. `r2` is the immutable catalogue revision; the
firmware ABI itself remains r1:

```conf
src/gz tdvp_apps_r2 https://vicliu624.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r2/riscv64
```

Do not manually alter that file or add generic OpenWrt, Debian, or arbitrary
`riscv64` feeds.

## Normal operator flow

```sh
sudo tdvp-opkg update
sudo tdvp-opkg list 'tdvp-*'
sudo tdvp-opkg info tdvp-gba
sudo tdvp-opkg install --download-only tdvp-gba
sudo tdvp-opkg install tdvp-gba
tdvp-gba
```

For a community package, use its exact published name instead. `tdvp-gba`
automatically pulls `sdl2`, `sdl2-ttf`, and `libmgba`; do not force individual
dependencies. If the immutable r1 package `tdvp-cardputer-zero-gba` is
installed, remove it before installing `tdvp-gba` so their launchers cannot
overlap. Do not use `--force-depends`, `--force-checksum`, or
`--no-check-certificate`.

## Expected failure cases

These failures are correct and must block installation:

- package index signature does not validate;
- public key is unknown or has been rotated without a firmware update;
- package architecture is not accepted;
- `tdvp-platform-abi` version does not match;
- package checksum differs from the signed index.

## Updating feed-managed userland

Only update feed-managed userland packages from this feed: shared libraries,
tools, desktop programs, and device applications. Do not run blanket `opkg
upgrade` against the base firmware; kernel, drivers, libc, dynamic loader,
desktop base stack, network stack and KPU runtime are firmware-managed
components.
