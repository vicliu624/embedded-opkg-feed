# Device bootstrap contract for TDVP K230 r1

[中文](DEVICE_BOOTSTRAP.zh-CN.md) | English (current)

This document defines the signed TDVP K230 r1 base-image contract. It is not
an ad-hoc command list for a production device.

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

option check_signature 1
option signature_type gpg-asc
option gpg_dir /etc/opkg/gpg
option gpg_trust_level TrustAny
```

Create `/var/lib/opkg/{lists,info}` and the status file in the image build.
Install the single ABI-specific r2 source separately in `/etc/opkg/tdvp-feed.conf`.
The feed revision is not a firmware ABI bump: the marker below remains r1.

```conf
src/gz tdvp_apps_r2 https://vicliu624.github.io/embedded-opkg-feed/feed/tdvp-k230-br2025.02.1-glibc2.33-rv64-lp64d-k6.6.36-r1/r2/riscv64
```

This avoids an untracked root filesystem where opkg cannot know what it owns,
and keeps the signed feed contract independent from the core opkg settings.

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

The r1 base image uses the existing opkg GPG ASCII-armoured backend
(`signature_type gpg-asc`). That target downloads `Packages.asc` and verifies
the unpacked `Packages` index; the feed additionally publishes
`Packages.gz.asc`, which separately signs the compressed `Packages.gz` file
for compatible tooling. The image contains only the public key
and imports it immediately before an operator invokes `tdvp-opkg`; package
trust must never delay `greetd` or desktop startup. No private signing material
belongs in the image.

The acceptance test must prove all four cases:

1. a valid index signature succeeds;
2. an altered `Packages.gz` fails;
3. an unknown signing key fails;
4. HTTPS certificate verification fails for an untrusted certificate.

Never use `--no-check-certificate`, `--force-checksum`, or `--force-depends`
in normal update instructions.
