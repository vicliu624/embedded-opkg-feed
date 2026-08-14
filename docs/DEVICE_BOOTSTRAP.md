# Device bootstrap contract for TDVP K230 r1

[中文](DEVICE_BOOTSTRAP.zh-CN.md) | English (current)

This document describes changes for the **next firmware image**, not ad-hoc
commands to run on a production device.

## 1. Correct the opkg state configuration

The target's opkg 0.7.0 rejects its current OpenWrt-style line:

```text
lists_dir ext /var/lib/opkg/lists
```

Use this target-compatible form instead:

```conf
dest root /

option lists_dir /var/lib/opkg/lists
option info_dir /var/lib/opkg/info
option status_file /var/lib/opkg/status
option tmp_dir /tmp

arch all 1
arch noarch 1
arch riscv64 10

# Add only after index-signature verification is implemented and tested.
src/gz tdvp_apps_r1 https://YOUR_GITHUB_ID.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/riscv64
```

Create `/var/lib/opkg/{lists,info}` and the status file in the image build.
This avoids an untracked root filesystem where opkg cannot know what it owns.

## 2. Register the ABI marker in the image

The firmware image must install a no-payload marker package before any public
application package is accepted:

```text
Package: tdvp-platform-abi
Version: 2025.02.1-k230.6.6.36-glibc2.33-rv64-lp64d-r1
Architecture: riscv64
Status: install ok installed
Description: ABI identity for TDVP K230 firmware r1
```

Generate this state entry during the Buildroot image build. Do not hand-edit a
live device's status database as a substitute for a release manifest.

## 3. Add real signature verification

The currently shipped libopkg contains signature-related code but has no
working verifier: it lacks `usign`, `opkg-key`, `gpg`, `gpgv`, and a linked
GPGME backend. Rebuild the firmware with one selected, tested verification
backend before enabling `check_signature`.

Preferred low-disruption choice: build the existing opkg line with its GPG
verification backend, include the minimal verifier runtime, and embed only the
repository public key. A smaller `usign` path is viable only after an
end-to-end integration test proves compatibility with this Buildroot opkg.

The acceptance test must prove all four cases:

1. a valid index signature succeeds;
2. an altered `Packages.gz` fails;
3. an unknown signing key fails;
4. HTTPS certificate verification fails for an untrusted certificate.

Never use `--no-check-certificate`, `--force-checksum`, or `--force-depends`
in normal update instructions.
