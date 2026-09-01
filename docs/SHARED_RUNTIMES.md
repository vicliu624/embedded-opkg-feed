# Shared runtime package contract

[中文](SHARED_RUNTIMES.zh-CN.md) | English (current)

The TDVP K230 feed has three reviewed package kinds:

```text
application       command-line tool, desktop program, device app, data, and documentation
shared-library    recipe-built runtime SONAME library reusable by applications
runtime           target-derived shared runtime, plugin, or runtime data
```

This is not a generic RISC-V repository. Every package is `riscv64`, belongs to one immutable TDVP feed revision, and receives an exact `tdvp-platform-abi` dependency from the platform manifest.

## Composable-ownership contract

From r4 forward, this is not an “application plus a few exception libraries” feed. It is a composable, distribution-style userland catalogue. The only runtime an application may assume implicitly from the base image is the ABI seed: all target dynamic loaders, glibc's `libc/libdl/libm/libpthread/librt`, `libgcc_s`, and `libstdc++`, alongside the kernel, drivers, and boot chain. Those components are not opkg-upgradeable.

**Every other dynamic SONAME included in a feed release has exactly one independently installable IPK owner in that release.** The catalogue is deliberately completed incrementally: a new application may expose a library that no prior release needed. Before the leaf application is published, that library must enter the new feed release as a reusable provider; it must not be statically bundled into the application or silently borrowed from the target rootfs. A release's runtime catalogue packages the non-ABI SONAMEs, runtime data and loadable modules that are selected from its verified target; examples include GTK3/GLib, Wayland/EGL/Mesa, ALSA/PulseAudio, SDL2, libmGBA, libcurl, libpng, libjpeg, libutf8proc, the FFmpeg/MPV stack, `gtk3-data`, `gdk-pixbuf-loaders`, `glib-networking`, `pulse-modules`, `tdvp-gdk-committed-compat`, `tdvp-hardware-runtime`, `tdvp-runtime-libexec`, and `shared-mime-info`. The release verifier scans `/usr/lib`, `/usr/libexec`, `/usr/local/lib`, and `/usr/local/libexec`; local library locations are included specifically so custom shared objects cannot remain implicit base-image dependencies.

`tdvp-gba`, `tdvp-netsurf`, `tdvp-mpv`, and `audacious` are therefore leaf applications. They do not carry static copies or borrow a general-purpose library from the base image; their exact versioned `Depends` relations acquire every direct runtime requirement. Audacious is split into a reusable `audacious-core` runtime (the three public `libaud*` SONAMEs), an `audacious-plugins` runtime (the private GTK3/FFmpeg/ALSA/PulseAudio module tree), and the `audacious` desktop leaf. The image can carry byte-identical compatibility copies so its first desktop boot does not rely on the network, but that never changes the dependency contract: release verification treats the feed package, not the base rootfs, as the provider of every non-ABI SONAME, private dynamic helper, plugin, or runtime module, and the installed IPK is the sole package owner. TDVP-owned shared objects belong in `/usr/lib`; `/usr/local/lib` is audited specifically so an accidental private shared object cannot become an undeclared image dependency.

The automatic closure checker reads ELF `NEEDED` entries; it cannot infer a
subprocess invoked by `exec`. A recipe that needs an external command must
state that command's IPK owner in `PACKAGE_DEPENDS`. If the selected target has
no such provider, add a normal tool package to the same feed release first.
This is an application/package dependency, not a platform-ABI or firmware
change; LoFiBox's `ffprobe` is the reference case.

A library is built or extracted once per ABI/feed release and is reused by all subsequent programs. Adding another application must not rebuild or statically bundle SDL, GTK, curl, image libraries, or any comparable general runtime.

## Recipe metadata

Each recipe declares both build ordering and installed runtime requirements:

```sh
PACKAGE_KIND='shared-library'        # or application / runtime
PACKAGE_RELEASES='r6'
PACKAGE_SECTION='libraries'          # e.g. libraries, utils, desktop, games
PACKAGE_BUILD_DEPENDS='sdl2'         # staging only
PACKAGE_DEPENDS='sdl2 (= 2.30.11-1)' # opkg runtime relationship
PACKAGE_AUTO_RUNTIME_DEPENDS=1       # derive remaining exact dependencies from ELF NEEDED
```

`build-all.sh` constructs one temporary `TDVP_FEED_STAGING_ROOT`. Library recipes install headers, CMake metadata and unversioned linker symlinks there only. The resulting `.ipk` may contain only runtime `lib*.so*` files plus the package's own licence/documentation paths. The platform catalogue also splits every non-ABI target SONAME, plugin, and runtime-data set into independent `runtime` packages and generates a SONAME → `Package (= Version)` owner map. Application recipes link against the same staging root and do not copy those libraries into their own payload.

## Mandatory release checks

Before an immutable feed is signed, the release build verifies:

- each non-ABI SONAME has exactly one feed provider;
- every non-ABI dynamically linked object already in `/usr/lib` or `/usr/libexec` has one byte-identical feed owner;
- every application's or module's direct `NEEDED` SONAME is covered by an exact declared dependency, never by the target rootfs as a back door;
- a base-image overlay is accepted only when file bytes, modes, and symlink targets are identical, making it a transfer of package ownership rather than a replacement;
- a shared runtime cannot write protected loader/glibc/libstdc++ files;
- two feed packages do not export the same ELF SONAME;
- newly introduced payload ELF files have no RPATH/RUNPATH; legacy target ELF may retain one only after a byte-identical audit;
- leaf applications cannot statically bundle or privately copy a general runtime library.

Use `TDVP_FEED_BASE_ROOT=<matching Buildroot target>` when building a feed with shared libraries. This is required; a library release cannot be signed on the basis of source metadata alone.

`tdvp-` is reserved for packages owned by the TDVP platform (for example, `tdvp-gba`); it is not a prefix for generic third-party libraries. Generic libraries keep their upstream names, while the feed's platform ABI dependency and `Architecture: riscv64` keep them in their safe installation domain.
