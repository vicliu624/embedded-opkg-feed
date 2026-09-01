# Feed snapshots and the stable channel

[中文](CHANNELS.zh-CN.md) | English (current)

TDVP firmware should ship infrequently, while application, runtime-library,
and desktop-program feeds can ship frequently. This repository separates an
**immutable snapshot** from the **device channel** to retain both reproducible
releases and field updates.

```text
Image (low frequency)
  public key + ABI identity + .../<PLATFORM_ID>/stable/<ARCH>

Feed (high frequency)
  .../<PLATFORM_ID>/r7/<ARCH>       immutable snapshot
  .../<PLATFORM_ID>/r8/<ARCH>       immutable snapshot
  .../<PLATFORM_ID>/stable/<ARCH>   complete view of the approved snapshot
```

## Invariants

- A public rN is never overwritten, re-signed, or deleted; an added application
  or dependency requires a new rN.
- `stable` is not a release. It is the ABI-fixed delivery channel configured by
  devices.
- `stable` may only promote one already verified rN in full. Every IPK,
  `Packages`, `Packages.gz`, `Packages.asc`, and `Packages.gz.asc` must be
  byte-identical to the source rN.
- Devices retain their existing opkg verification of detached Packages
  signatures, package hashes, architecture, and exact `tdvp-platform-abi`
  dependencies. `release.json` is auditable descriptive metadata, not a new
  trust root.
- Rollback promotes a previously verified rN back to `stable`; it never edits
  that old rN.

## Release operation

After a candidate has passed its build, device validation, and offline signing,
stage it as an immutable snapshot and then explicitly promote it:

```sh
bash scripts/stage-site.sh --platform tdvp-k230-r1 --release r8 \
  /absolute/path/to/signed/r8/riscv64

bash scripts/promote-stable-channel.sh --platform tdvp-k230-r1 --release r8
bash scripts/verify-stable-channel.sh --platform tdvp-k230-r1
```

The last command verifies signatures, ABI dependencies, index hashes, and the
per-package byte identity from rN to `stable`. Commit the snapshot and stable
change together on the protected `release` branch; the Pages workflow verifies
the relation again before deployment.

Never promote an unsigned candidate, an arbitrary local build directory, or a
development branch to `stable`. Firmware must never configure an rN URL,
because that would again turn each application release into a firmware release.

## When an image must be rebuilt

Adding or updating LoFiBox, `ffprobe`, shared libraries, icons, or desktop
applications requires only a Feed release and promotion. A new TDVP base image
and `PLATFORM_ID` are required only when ABI compatibility changes: the kernel
or drivers, glibc or the dynamic loader, core desktop stack, opkg semantics, or
the public release key.
