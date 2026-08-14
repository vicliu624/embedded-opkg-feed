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

The currently inspected TDVP K230 image does not meet items 1, 2, or 4. Follow
[DEVICE_BOOTSTRAP.md](DEVICE_BOOTSTRAP.md) as part of the next firmware build.

## Configure the TDVP K230 r1 feed

After that firmware is deployed, add this **single, ABI-specific** source to
its canonical `/etc/opkg/opkg.conf`:

```conf
src/gz tdvp_apps_r1 https://YOUR_GITHUB_ID.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/riscv64
```

Do not add generic OpenWrt, Debian, or arbitrary `riscv64` feeds.

## Normal operator flow

```sh
opkg update
opkg list 'tdvp-*'
opkg info tdvp-hello
opkg install --download-only tdvp-hello
opkg install tdvp-hello
tdvp-hello
```

For a community package, use its exact published name instead. Do not use
`--force-depends`, `--force-checksum`, or `--no-check-certificate`.

## Expected failure cases

These failures are correct and must block installation:

- package index signature does not validate;
- public key is unknown or has been rotated without a firmware update;
- package architecture is not accepted;
- `tdvp-platform-abi` version does not match;
- package checksum differs from the signed index.

## Updating applications

Only update application packages from this feed. Do not run blanket
`opkg upgrade` against the base firmware; kernel, drivers, libc, network stack
and KPU runtime are firmware-managed components.
