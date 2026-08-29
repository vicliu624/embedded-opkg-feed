# TDVP GBA package

`tdvp-gba` is the TDVP K230 feed package for the public
[`cardputer-zero-gameboy-emulator`](https://github.com/vicliu624/cardputer-zero-gameboy-emulator)
source revision pinned in `package.env`.

Unlike the legacy immutable r1 package, this release does not bundle SDL2 or
mGBA into the emulator executable.  It has an explicit shared runtime closure:

```text
tdvp-gba
  ├─ sdl2
  ├─ sdl2-ttf
  └─ libmgba
```

Each package additionally depends on the exact `tdvp-platform-abi` installed
by the matching firmware.  `build-all.sh` builds the shared libraries once into
an ephemeral release staging sysroot, then builds this frontend dynamically
against that sysroot.  The final `.ipk` contains only the emulator, launcher,
desktop entry, icon, and application documentation.

The launcher is `/usr/bin/tdvp-gba`; it starts a normal Wayland client below
Labwc and never takes DRM/KMS ownership from the desktop.

The r1 package named `tdvp-cardputer-zero-gba` remains immutable for historical
devices.  On a device migrated to the r2 feed, remove that legacy package
before installing `tdvp-gba` so their old and new launchers cannot overlap.
