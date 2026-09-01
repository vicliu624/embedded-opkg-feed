# Release checklist

[中文](RELEASE.zh-CN.md) | English (current)

1. Select one declared platform and build with its pinned SDK/container, never
   with host-native RISC-V packages.
2. Verify every package has the selected platform architecture and exact ABI
   marker dependency.
3. Verify application payloads do not enter protected firmware areas; a shared library may install only reviewed `/usr/lib/lib*.so*` files and may not replace a base-image file.
4. Generate `Packages` and reproducible `Packages.gz`.
5. Verify index hashes, package control metadata, base-image file collisions, SONAME ownership, and dynamic dependency closure.
6. Sign `Packages.gz` on the protected signing host.
7. Verify the detached signature with the committed public key.
8. Stage the immutable feed below `site/feed/<PLATFORM_ID>/rN/riscv64/`. The already published r1 path remains byte-for-byte unchanged.
9. Promote the verified snapshot in full with `scripts/promote-stable-channel.sh --platform <platform> --release rN`, then run `scripts/verify-stable-channel.sh`. This is the only operation allowed to change the device-facing feed directory.
10. Stage the generated public files. Generic `.gitignore` excludes `.ipk`, so use `git add -f` for `*.ipk` in both rN and stable; a Packages index without its IPKs is not a publishable opkg source.
11. Commit the generated public files to the protected `release` branch.
12. Let the Pages workflow publish only after signature verification, rN immutability, and the stable-channel relationship succeed.
13. On a non-production K230, test valid install, rejected bad signature,
    rejected wrong ABI, uninstall, and rollback before release approval.

Rollback does not rewrite an old rN: promote the previously verified snapshot
to `stable` again and pass the same Pages release gate.
