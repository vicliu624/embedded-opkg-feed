# TDVP K230 GBA Emulator Package

This recipe packages the public
[`vicliu624/cardputer-zero-gameboy-emulator`](https://github.com/vicliu624/cardputer-zero-gameboy-emulator)
source tree for the `tdvp-k230-r1` platform. The exact upstream repository and
40-character commit are locked in `package.env`; `build.sh` refuses a checkout
with a different origin, a different `HEAD`, or uncommitted changes. This makes
the feed recipe traceable to one reviewable source revision rather than to an
accidental sibling working directory.

It uses the application's `tdvp-k230` profile: an application-local DRM/KMS
scanout buffer for a dedicated 410x189 large-screen UI. The canvas is presented
at a 3x integer scale (1230x567 at `(1,0)`) on the K230's 1232x568 landscape
panel. It uses `/dev/dri/card0`, never fbdev, and restores the prior KMS CRTC
state when the application exits.

The GBA source remains a native 240x160 frame. It occupies a 720x480 physical
viewport after the KMS scale, with expanded application information/control
rails and an F1--F5 command bar using the rest of the panel. No fractional
scaling, stretching, or cropping is used.

## Build Inputs

The build hook requires the exact TDVP Buildroot 2025.02.1 SDK/sysroot. It
discovers Buildroot's `toolchainfile.cmake` below `--sdk-root`, or accepts an
explicit `TDVP_K230_TOOLCHAIN_FILE`. It does not download a compiler, prebuilt
binary, or source archive. The recipe pins `pkg-config` to that target sysroot
so a WSL or Linux host library cannot enter the RISC-V build, and uses the
same K230 toolchain's `strip` binary for the release executable.

By default the pinned source checkout is expected beside this feed repository:

```text
../cardputer-zero-gameboy-emulator
```

Set `TDVP_CARDPUTER_ZERO_GBA_SOURCE_DIR` when it lives elsewhere. It must still
be a clean checkout of the exact `SOURCE_REVISION` named in `package.env`. From
a Linux or WSL checkout, build the complete feed with:

```sh
TDVP_SDK_ROOT=/path/to/tdvp-k230-sdk \
TDVP_CARDPUTER_ZERO_GBA_SOURCE_DIR=/path/to/cardputer-zero-gameboy-emulator \
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
tdvp-k230` and deliberately does not force an SDL video driver. It does not
write to protected firmware paths.
