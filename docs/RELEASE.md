# Release checklist

[中文](RELEASE.zh-CN.md) | English (current)

1. Select one declared platform and build with its pinned SDK/container, never
   with host-native RISC-V packages.
2. Verify every package has the selected platform architecture and exact ABI
   marker dependency.
3. Verify payload paths do not enter protected firmware areas.
4. Generate `Packages` and reproducible `Packages.gz`.
5. Verify index hashes and package control metadata.
6. Sign `Packages.gz` on the protected signing host.
7. Verify the detached signature with the committed public key.
8. Stage the immutable feed below `site/feed/<PLATFORM_ID>/riscv64/`.
9. Commit the generated public files to the protected `release` branch.
10. Let the Pages workflow publish only after signature verification succeeds.
11. On a non-production K230, test valid install, rejected bad signature,
    rejected wrong ABI, uninstall, and rollback before release approval.
