# TDVP K230 GBA Emulator Package

This recipe packages the public
[`vicliu624/cardputer-zero-gameboy-emulator`](https://github.com/vicliu624/cardputer-zero-gameboy-emulator)
source tree for the `tdvp-k230-r1` platform. The exact upstream repository and
40-character commit are locked in `package.env`; `build.sh` refuses a checkout
with a different origin, a different `HEAD`, or uncommitted changes. This makes
the feed recipe traceable to one reviewable source revision rather than to an
accidental sibling working directory.

It uses the application's `tdvp-k230` profile: a labwc Wayland client for a
dedicated 410x189 large-screen UI. Labwc retains DRM master, the native KMS
scanout, and panel orientation, while the application canvas is presented at a
3x integer scale (1230x567 at `(1,0)`) on the K230's 1232x568 landscape output.
It never uses fbdev or attempts to modeset the system CRTC.

The GBA source remains a native 240x160 frame. It occupies a 720x480 physical
viewport after the Wayland scale, with expanded application information/control
rails and an F1--F5 command bar using the rest of the panel. No fractional
scaling, stretching, or cropping is used.

## Build Inputs

The build hook requires the exact TDVP Buildroot 2025.02.1 SDK/sysroot. It
discovers Buildroot's `toolchainfile.cmake` below `--sdk-root`, or accepts an
explicit `TDVP_K230_TOOLCHAIN_FILE`. It does not download a compiler, prebuilt
binary, or source archive. The recipe pins `pkg-config` to that target sysroot
so a WSL or Linux host library cannot enter the RISC-V build, and uses the
same K230 toolchain's `strip` binary for the release executable.

The K230 SDK currently lacks the Wayland development metadata despite the
firmware providing the needed runtime libraries. Set
`TDVP_K230_WAYLAND_SDK_OVERLAY` to a firmware-matched overlay containing the
target Wayland/EGL/XKB headers, pkg-config files, and SONAME-bearing
libraries. The finished package dynamically uses the base-firmware libraries;
it does not package or replace them. SDL creates the Wayland window and handles
input, while the application attaches CPU-owned `wl_shm` XRGB buffers directly
to that window's Wayland surface. It intentionally disables SDL OpenGL ES so
Mesa `swrast` cannot become the presentation path.

The overlay must include the firmware's `libffi.so` link input because the
target `libwayland-client.so` depends on the matching `libffi.so.8` ABI.

It must also include the target `libpulse.so` and `libasound.so` development
inputs. SDL dynamically loads PulseAudio as the K230 desktop's primary audio
path and dynamically loads ALSA as a fallback, so those runtime libraries
remain owned by the base firmware and are not copied into the package.

The TDVP GCC 14.1 RISC-V backend has an internal-compiler-error path while
compiling mGBA's generated ARM opcode table with shrink-wrap enabled. The
recipe preserves the normal `-O2` release optimization level and disables only
that compiler pass for C sources, ensuring reproducible package builds without
changing the emulator's runtime platform contract.

The ABI-matched base firmware owns the generic `Games` category in the TDVP
panel. The emulator package owns only `tdvp-cardputer-zero-gba.desktop`, which
declares `Categories=Game;Emulator;` and is discovered by that category rule.
No feed package replaces `/etc/xdg/menus/lxde-applications.menu`.

The desktop entry uses the package-owned absolute icon path rather than a
theme-name lookup. This avoids a generic menu icon when the base firmware's
pre-generated hicolor icon cache cannot be refreshed by a feed package.

By default the pinned source checkout is expected beside this feed repository:

```text
../cardputer-zero-gameboy-emulator
```

Set `TDVP_CARDPUTER_ZERO_GBA_SOURCE_DIR` when it lives elsewhere. It must still
be a clean checkout of the exact `SOURCE_REVISION` named in `package.env`. From
a Linux or WSL checkout, first export the Wayland development overlay from the
same completed firmware build that will run the package:

```sh
bash ./scripts/prepare-tdvp-wayland-sdk-overlay.sh \
  /path/to/tdvp-firmware-output/k230_canmv_t_display_rm69a10_labwc_desktop_defconfig \
  .tdvp-sdk-overlay
```

The bridge refuses to replace an existing overlay and records the firmware
configuration hash in `tdvp-sdk-overlay.manifest`. It copies only headers,
pkg-config metadata, and link inputs; it never becomes package payload. Build
the complete feed with:

```sh
TDVP_SDK_ROOT=/path/to/tdvp-k230-sdk \
TDVP_CARDPUTER_ZERO_GBA_SOURCE_DIR=/path/to/cardputer-zero-gameboy-emulator \
TDVP_K230_WAYLAND_SDK_OVERLAY="$PWD/.tdvp-sdk-overlay" \
./scripts/build-all.sh --platform tdvp-k230-r1 --output dist
```

The build creates `root/` only as an intermediate package payload. It is
ignored by Git. Do not commit that directory's generated executable, `.ipk`,
index, or signature.

## Installed Files

```text
/opt/tdvp-cardputer-zero-gba/cardputer-zero-gba
/usr/bin/cardputer-zero-gba
/usr/share/applications/tdvp-cardputer-zero-gba.desktop
/usr/share/icons/hicolor/128x128/apps/cardputer-zero-gba.png
/usr/share/doc/tdvp-cardputer-zero-gba/
```

`/usr/bin/cardputer-zero-gba` invokes the binary with `--device-profile
tdvp-k230` and selects SDL's Wayland driver. It does not write to protected
firmware paths, menu definitions, or display configuration.

## Licence notices

The application itself is MIT licensed. The package statically bundles the
pinned SDL2 and mGBA source revisions, so the payload also installs their
licence texts as `LICENSE.SDL-zlib.txt` and `LICENSE.mGBA-MPL-2.0.txt` beneath
`/usr/share/doc/tdvp-cardputer-zero-gba/`. The source locks in `package.env`
and the source repository's Git submodule commits identify the corresponding
reviewable dependency revisions.
