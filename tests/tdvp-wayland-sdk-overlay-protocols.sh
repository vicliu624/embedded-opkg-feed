#!/usr/bin/env bash
# The compact incremental SDK cache intentionally omits Buildroot build trees.
# Verify that the SDK bridge takes its protocol XML from the retained target
# tree and that the common validation contract rejects an incomplete bridge.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
temporary=$(mktemp -d)
cleanup() { rm -rf -- "$temporary"; }
trap cleanup EXIT

output="$temporary/output"
sysroot="$output/host/riscv64-buildroot-linux-gnu/sysroot"
include="$sysroot/usr/include"
lib="$sysroot/usr/lib"
pc="$lib/pkgconfig"
mkdir -p "$output/host/share/buildroot" "$include" "$lib" "$pc" \
  "$output/target/usr/share/wayland-protocols/unstable/linux-dmabuf" \
  "$temporary/dl" "$temporary/freetype-2.13.3/include/freetype"
printf '%s\n' 'set(CMAKE_SYSTEM_NAME Linux)' >"$output/host/share/buildroot/toolchainfile.cmake"
printf '%s\n' 'fixture' >"$output/.config"

for header in wayland-client.h wayland-client-core.h wayland-client-protocol.h wayland-util.h zlib.h; do
  printf '%s\n' '/* fixture */' >"$include/$header"
done
mkdir -p "$include/EGL" "$include/alsa" "$include/pulse" "$include/xkbcommon"
printf '%s\n' '/* fixture */' >"$include/EGL/egl.h"
printf '%s\n' '/* fixture */' >"$include/alsa/asoundlib.h"
printf '%s\n' '/* fixture */' >"$include/pulse/pulseaudio.h"
printf '%s\n' '/* fixture */' >"$include/xkbcommon/xkbcommon.h"
printf '%s\n' '/* fixture */' >"$temporary/freetype-2.13.3/include/ft2build.h"
printf '%s\n' '/* fixture */' >"$temporary/freetype-2.13.3/include/freetype/freetype.h"
tar -cJf "$temporary/dl/freetype-2.13.3.tar.xz" -C "$temporary" freetype-2.13.3
freetype_sha=$(sha256sum "$temporary/dl/freetype-2.13.3.tar.xz" | awk '{print $1}')
for package in wayland-client wayland-cursor wayland-egl xkbcommon alsa libpulse freetype2; do
  printf '%s\n' "Name: $package" >"$pc/$package.pc"
done
for library in wayland-client wayland-cursor wayland-egl xkbcommon EGL asound pulse ffi freetype; do
  : >"$lib/lib$library.so"
done
printf '%s\n' '<protocol name="linux_dmabuf_v1"/>' >"$output/target/usr/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml"

overlay="$temporary/overlay"
TDVP_FREETYPE_SOURCE_ARCHIVE="$temporary/dl/freetype-2.13.3.tar.xz" \
TDVP_FREETYPE_SOURCE_SHA256="$freetype_sha" \
  bash "$repo_root/scripts/prepare-tdvp-wayland-sdk-overlay.sh" "$output" "$overlay"
test -f "$overlay/share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml"
test -f "$overlay/include/freetype/freetype.h"
test -f "$overlay/include/ft2build.h"
grep -Fq 'share/wayland-protocols/unstable/linux-dmabuf/linux-dmabuf-unstable-v1.xml' "$overlay/SHA256SUMS"

# shellcheck source=/dev/null
source "$repo_root/scripts/tdvp-k230-sdk.sh"
TDVP_K230_WAYLAND_SDK_OVERLAY="$overlay"
tdvp_require_wayland_sdk_overlay

echo 'Wayland SDK overlay protocol bridge: PASS'
