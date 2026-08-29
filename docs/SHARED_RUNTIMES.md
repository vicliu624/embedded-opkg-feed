# Shared runtime package contract

[中文](SHARED_RUNTIMES.zh-CN.md) | English (current)

The TDVP K230 feed can publish two reviewed package kinds:

```text
application       command-line tool, desktop program, device app, data, and documentation
shared-library    runtime SONAME files used by more than one application
```

This is not a generic RISC-V repository. Every package is `riscv64`, belongs
to one immutable TDVP feed revision, and receives an exact
`tdvp-platform-abi` dependency from the platform manifest.

## Ownership boundary

The Buildroot image owns the components needed to boot and operate the desktop:
the dynamic loader, glibc, libgcc/libstdc++, kernel/driver stack, GTK/Wayland,
NetworkManager, PulseAudio/ALSA, and their required base dependencies. They
must not be duplicated or upgraded by opkg.

The feed is the distribution catalogue for userland software and reusable
runtimes, such as `sdl2`, `sdl2-ttf`, and `libmgba`. It is intended to grow
with normal Linux distribution categories: shared libraries, CLI tools,
desktop programs, and hardware-specific applications. A library is compiled
once per ABI/feed release and may then be depended on by any number of
packages. The firmware also registers its seed/base packages in opkg's
installed database so the package graph does not treat the already-present
desktop runtime as an untracked black box.

## Recipe metadata

Each recipe declares both build ordering and installed runtime requirements:

```sh
PACKAGE_KIND='shared-library'       # or application
PACKAGE_RELEASES='r2'
PACKAGE_SECTION='libraries'         # e.g. libraries, utils, desktop, games
PACKAGE_BUILD_DEPENDS='sdl2'        # staging only
PACKAGE_DEPENDS='sdl2 (= 2.30.11-1)' # opkg runtime relationship
```

`build-all.sh` constructs one temporary `TDVP_FEED_STAGING_ROOT`. Library
recipes install headers, CMake metadata and unversioned linker symlinks there
only. The resulting `.ipk` may contain only runtime `lib*.so*` files plus the
package's own licence/documentation paths. Application recipes link against the
same staging root and do not copy those libraries into their own payload.

## Mandatory release checks

Before an immutable feed is signed, the release build verifies:

- no feed file replaces a matching target-root file;
- a shared runtime cannot write protected loader/libc/libstdc++ files;
- two feed packages do not export the same ELF SONAME;
- all payload ELF files have no RPATH/RUNPATH;
- each direct `NEEDED` SONAME is supplied by the base rootfs or a declared
  feed dependency.

Use `TDVP_FEED_BASE_ROOT=<matching Buildroot target>` when building a feed
with shared libraries. This is required; a library release cannot be signed on
the basis of source metadata alone.

`tdvp-` is reserved for packages owned by the TDVP platform (for example,
`tdvp-gba`); it is not a prefix for generic third-party libraries. Generic
libraries keep their upstream names, while the feed's platform ABI dependency
and `Architecture: riscv64` keep them in their safe installation domain.
