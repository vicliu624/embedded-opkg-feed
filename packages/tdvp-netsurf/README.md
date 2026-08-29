# TDVP K230 NetSurf Browser Package

`tdvp-netsurf` is an optional, normal GTK3 desktop browser for the
`tdvp-k230-r1` firmware ABI.  It deliberately does not use kiosk Cog or
WebKit.  The base image has no broken browser menu item; after this signed
package is installed, Labwc discovers the supplied `Network;WebBrowser;`
desktop entry in the normal application menu.

The package is built from NetSurf 3.10 using the same Buildroot 2025.02.1
profile that produced the firmware. Its direct runtime SONAMEs are checked
against that profile's `target/` as an ABI reference before packaging, then
resolved by the r4 feed owner map into exact `Depends`. It therefore contains
the browser binary and NetSurf resources only; GTK3, TLS, Curl, OpenSSL, image,
font, GLib, and Wayland libraries stay independently installable feed packages
rather than firmware-owned or browser-bundled copies.

## Build contract

The source archive and SHA-256 are pinned in `package.env` and checked against
the matching Buildroot `package/netsurf/netsurf.hash`.  The standard feed build
entry point requires the completed profile's `host/` SDK and derives the
matching profile output from its parent directory:

```sh
TDVP_SDK_ROOT=/path/to/tdvp-firmware-output/k230_canmv_t_display_rm69a10_labwc_desktop_defconfig/host \
./scripts/build-all.sh --platform tdvp-k230-r1 --output dist
```

`TDVP_NETSURF_BUILDROOT_OUTPUT` remains an optional explicit override for a
reviewed release environment, but it must resolve to the same parent directory
as `TDVP_SDK_ROOT`; a mismatch is rejected.

The hook temporarily enables only the Buildroot NetSurf GTK3 package and
stages the versioned patch in `patches/`.  That patch replaces an unnecessary
host-side XPM image-loader requirement with the existing PNG icon while
retaining NetSurf's `netsurf.xpm` GTK resource alias.  The hook saves and
restores the profile `.config` by SHA-256, installs NetSurf only into a private
temporary root, and removes its staged core-package patch on exit.  It never
writes to the firmware's `target/` directory or produces an SD-card image.

`root/` is generated package payload and is intentionally ignored by Git.
Do not commit it, an `.ipk`, a package index, or any release signature.

## Installed files

```text
/usr/bin/netsurf-gtk3
/usr/share/netsurf/
/usr/share/applications/tdvp-netsurf.desktop
/usr/share/icons/hicolor/128x128/apps/tdvp-netsurf.png
/usr/share/doc/tdvp-netsurf/COPYING
```

The complete installed payload is approximately 6 MiB before IPK compression.
The target executable is stripped with the same K230 SDK toolchain used for
the firmware, has no RPATH/RUNPATH, is gated by the exact
`tdvp-platform-abi` dependency injected by the feed builder, and gets exact
versioned dependencies for each non-ABI direct runtime SONAME.

## Device use

After the feed release has been signed and published, install it on an
ABI-matched device with:

```sh
sudo tdvp-opkg update
sudo tdvp-opkg install tdvp-netsurf
```

Open **NetSurf Web Browser** from the normal Network menu.  The program is a
regular Labwc window, so the existing desktop controls, touch input, keyboard,
and `Alt+F4` close action remain applicable.
