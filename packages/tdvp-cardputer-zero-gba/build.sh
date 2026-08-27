#!/usr/bin/env bash
# Build the TDVP K230 payload from local, reviewable source and the exact
# Buildroot SDK. The generated root/ tree is intentionally not committed.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <tdvp-sdk-root>" >&2
  exit 64
fi

platform_slug=$2
sdk_root=$4
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)

# package.env is reviewed input. Source provenance is intentionally checked in
# this build hook as well as documented for reviewers; build-ipk.sh runs in a
# different process and its sourced variables do not reach this script.
# shellcheck source=/dev/null
source "$package_dir/package.env"
: "${SOURCE_REPOSITORY:?package.env must set SOURCE_REPOSITORY}"
: "${SOURCE_REVISION:?package.env must set SOURCE_REVISION}"
[[ "$SOURCE_REVISION" =~ ^[0-9a-f]{40}$ ]] || {
  echo "SOURCE_REVISION must be a full lowercase Git commit SHA: $SOURCE_REVISION" >&2
  exit 61
}

[[ "$platform_slug" == 'tdvp-k230-r1' ]] || {
  echo "tdvp-cardputer-zero-gba does not support platform: $platform_slug" >&2
  exit 65
}
[[ -n "$sdk_root" && -d "$sdk_root" ]] || {
  echo 'TDVP K230 build requires the matching Buildroot SDK root.' >&2
  exit 66
}
command -v git >/dev/null || {
  echo 'TDVP K230 build requires Git to verify the pinned application source.' >&2
  exit 62
}

source_root=${TDVP_CARDPUTER_ZERO_GBA_SOURCE_DIR:-"$feed_root/../cardputer-zero-gameboy-emulator"}
source_root=$(cd -- "$source_root" && pwd)
source_top_level=$(git -C "$source_root" rev-parse --show-toplevel 2>/dev/null) || {
  echo "cardputer-zero-gba source is not a Git checkout: $source_root" >&2
  exit 63
}
[[ "$source_top_level" == "$source_root" ]] || {
  echo "source path must be the checkout root, not a subdirectory: $source_root" >&2
  exit 64
}

canonical_repository_url() {
  local url=$1
  url=${url%/}
  url=${url%.git}
  case "$url" in
    git@github.com:*) url="https://github.com/${url#git@github.com:}" ;;
    ssh://git@github.com/*) url="https://github.com/${url#ssh://git@github.com/}" ;;
  esac
  printf '%s\n' "$url"
}

source_origin=$(git -C "$source_root" config --get remote.origin.url || true)
[[ -n "$source_origin" ]] || {
  echo "source checkout has no origin remote: $source_root" >&2
  exit 65
}
[[ "$(canonical_repository_url "$source_origin")" == "$(canonical_repository_url "$SOURCE_REPOSITORY")" ]] || {
  echo "source origin does not match SOURCE_REPOSITORY: $source_origin" >&2
  exit 66
}
[[ "$(git -C "$source_root" rev-parse HEAD)" == "$SOURCE_REVISION" ]] || {
  echo "source HEAD does not match SOURCE_REVISION: $source_root" >&2
  exit 67
}
git -C "$source_root" diff --quiet || {
  echo "source checkout has unstaged changes: $source_root" >&2
  exit 68
}
git -C "$source_root" diff --cached --quiet || {
  echo "source checkout has staged changes: $source_root" >&2
  exit 69
}
if git -C "$source_root" submodule status --recursive | grep -qE '^[+-]'; then
  echo 'source checkout has missing or wrong bundled submodules; use git clone --recurse-submodules.' >&2
  exit 70
fi
git -C "$source_root" submodule foreach --recursive \
  'git diff --quiet && git diff --cached --quiet' || {
  echo "source checkout has modified bundled dependencies: $source_root" >&2
  exit 71
}
[[ -f "$source_root/CMakeLists.txt" ]] || {
  echo "cardputer-zero-gba source tree is invalid: $source_root" >&2
  exit 72
}
[[ -f "$source_root/packaging/tdvp-k230/cardputer-zero-gba" ]] || {
  echo "source tree is missing the TDVP K230 launcher: $source_root" >&2
  exit 73
}

toolchain_file=${TDVP_K230_TOOLCHAIN_FILE:-}
if [[ -z "$toolchain_file" ]]; then
  for candidate in \
    "$sdk_root/host/share/buildroot/toolchainfile.cmake" \
    "$sdk_root/share/buildroot/toolchainfile.cmake" \
    "$sdk_root/toolchainfile.cmake"; do
    if [[ -f "$candidate" ]]; then
      toolchain_file=$candidate
      break
    fi
  done
fi
if [[ -z "$toolchain_file" ]]; then
  toolchain_file=$(find "$sdk_root" -type f -path '*/share/buildroot/toolchainfile.cmake' -print -quit)
fi
[[ -n "$toolchain_file" && -f "$toolchain_file" ]] || {
  echo 'could not find a Buildroot CMake toolchain file; set TDVP_K230_TOOLCHAIN_FILE.' >&2
  exit 74
}

# CMake's toolchain file sets PKG_CONFIG_SYSROOT_DIR, but pkg-config still
# falls back to the build host's default .pc directories unless LIBDIR is
# pinned. That can otherwise make an x86 WSL dbus/pulse/EGL dependency leak
# into a RISC-V build. The K230 sysroot need not provide .pc files for the
# static SDL configuration below; an empty target-only search path is correct.
toolchain_host_dir=$(cd -- "$(dirname -- "$toolchain_file")/../.." && pwd)
toolchain_sysroot=$(find "$toolchain_host_dir" -type d -name sysroot -print -quit)
[[ -n "$toolchain_sysroot" && -d "$toolchain_sysroot" ]] || {
  echo "could not find the target sysroot beside Buildroot toolchain file: $toolchain_file" >&2
  exit 75
}
wayland_sdk_overlay=${TDVP_K230_WAYLAND_SDK_OVERLAY:-}
[[ -n "$wayland_sdk_overlay" && -d "$wayland_sdk_overlay" ]] || {
  echo 'TDVP K230 build requires TDVP_K230_WAYLAND_SDK_OVERLAY with the firmware-matched Wayland client development ABI.' >&2
  exit 78
}
[[ -f "$wayland_sdk_overlay/include/wayland-client.h" &&
   -f "$wayland_sdk_overlay/include/xkbcommon/xkbcommon.h" &&
   -f "$wayland_sdk_overlay/include/EGL/egl.h" &&
   -f "$wayland_sdk_overlay/lib/pkgconfig/wayland-client.pc" &&
   -f "$wayland_sdk_overlay/lib/pkgconfig/xkbcommon.pc" ]] || {
  echo "invalid TDVP_K230_WAYLAND_SDK_OVERLAY: $wayland_sdk_overlay" >&2
  exit 79
}
strip_tool=${TDVP_K230_STRIP:-"$toolchain_host_dir/bin/riscv64-unknown-linux-gnu-strip"}
[[ -x "$strip_tool" ]] || {
  echo "could not find the K230 target strip tool: $strip_tool" >&2
  exit 76
}
export PKG_CONFIG_SYSROOT_DIR="$toolchain_sysroot"
export PKG_CONFIG_LIBDIR="$wayland_sdk_overlay/lib/pkgconfig:$toolchain_sysroot/usr/lib/pkgconfig:$toolchain_sysroot/usr/share/pkgconfig"
export PKG_CONFIG_PATH=''

for tool in cmake install ninja; do
  command -v "$tool" >/dev/null || {
    echo "required build tool is missing: $tool" >&2
    exit 77
  }
done

build_dir=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_dir"; }
trap cleanup EXIT

# This is a build-owned directory, not an arbitrary caller-supplied path.
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"

cmake -S "$source_root" -B "$build_dir" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$toolchain_file" \
  -DBUILD_TESTING=OFF \
  -DCZ_GBA_FETCH_SDL2=OFF \
  -DCZ_GBA_BUNDLE_SDL2=ON \
  -DCZ_GBA_PREFER_BUNDLED_SDL2=ON \
  -DCZ_GBA_SDL_SHARED=OFF \
  -DCZ_GBA_SDL_STATIC=ON \
  -DCZ_GBA_REQUIRE_K230_DRM=ON \
  -DSDL_WAYLAND=ON \
  -DSDL_WAYLAND_SHARED=ON \
  -DSDL_WAYLAND_LIBDECOR=OFF \
  -DSDL_WAYLAND_QT_TOUCH=OFF \
  -DSDL_KMSDRM=OFF \
  -DSDL_X11=OFF \
  -DSDL_VIVANTE=OFF \
  -DSDL_RPI=OFF \
  -DSDL_VIDEO=ON \
  -DSDL_OPENGL=OFF \
  -DSDL_OPENGLES=ON \
  -DSDL_VULKAN=OFF \
  -DSDL_DBUS=OFF \
  -DSDL_IBUS=OFF \
  -DSDL_PULSEAUDIO=OFF \
  -DSDL_SNDIO=OFF \
  -DSDL_ALSA=OFF \
  -DSDL_HIDAPI=OFF \
  -DSDL_JOYSTICK=OFF \
  -DSDL_HAPTIC=OFF \
  -DSDL_SENSOR=OFF \
  -DCZ_GBA_USE_SYSTEM_MGBA=OFF \
  -DCZ_GBA_BUNDLE_MGBA=ON
cmake --build "$build_dir" --target cardputer-zero-gba --parallel
"$strip_tool" --strip-unneeded "$build_dir/cardputer-zero-gba"

install -Dm 0755 "$build_dir/cardputer-zero-gba" \
  "$payload_dir/opt/tdvp-cardputer-zero-gba/cardputer-zero-gba"
install -Dm 0755 "$source_root/packaging/tdvp-k230/cardputer-zero-gba" \
  "$payload_dir/usr/bin/cardputer-zero-gba"
install -Dm 0644 "$source_root/packaging/tdvp-k230/tdvp-cardputer-zero-gba.desktop" \
  "$payload_dir/usr/share/applications/tdvp-cardputer-zero-gba.desktop"
install -Dm 0644 "$source_root/assets/icons/cardputer-zero-gba-128.png" \
  "$payload_dir/usr/share/icons/hicolor/128x128/apps/cardputer-zero-gba.png"
install -Dm 0644 "$source_root/README.md" \
  "$payload_dir/usr/share/doc/tdvp-cardputer-zero-gba/README.md"
install -Dm 0644 "$source_root/LICENSE" \
  "$payload_dir/usr/share/doc/tdvp-cardputer-zero-gba/LICENSE"
install -Dm 0644 "$source_root/extern/SDL/LICENSE.txt" \
  "$payload_dir/usr/share/doc/tdvp-cardputer-zero-gba/LICENSE.SDL-zlib.txt"
install -Dm 0644 "$source_root/extern/mgba/LICENSE" \
  "$payload_dir/usr/share/doc/tdvp-cardputer-zero-gba/LICENSE.mGBA-MPL-2.0.txt"
