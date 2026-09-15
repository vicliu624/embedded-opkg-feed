#!/usr/bin/env bash
# Cross-build the TDVP LoFiBox xdg_toplevel target. The K230 Buildroot host
# tools generate protocol bindings, while every target header and link input
# comes from the matching firmware SDK bridge rather than the release-builder
# host.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "vicliu624-lofibox-widget does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
# shellcheck source=/dev/null
source "$package_dir/package.env"
# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$feed_root/scripts/tdvp-k230-sdk.sh"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$feed_root/support/buildroot-feed-session.sh"

source_root=${TDVP_LOFIBOX_SOURCE_DIR:-"$feed_root/../LoFiBox-Zero"}
source_root=$(tdvp_verify_git_source "$source_root" "$SOURCE_REPOSITORY" "$SOURCE_REVISION")
tdvp_require_k230_sdk "$4"
tdvp_require_wayland_sdk_overlay
tdvp_prepare_pkg_config

buildroot_output=$(tdvp_buildroot_output_from_sdk "$4" "${TDVP_LOFIBOX_BUILDROOT_OUTPUT:-}")
scanner="$buildroot_output/host/bin/wayland-scanner"
[[ -x "$scanner" ]] || {
  echo "matching Buildroot wayland-scanner is missing: $scanner" >&2
  exit 66
}
[[ -d "$buildroot_output/build" ]] || {
  echo "matching Buildroot package build directory is missing: $buildroot_output/build" >&2
  exit 67
}

xdg_shell_xml=$(find "$buildroot_output/build" -type f \
  -path '*/stable/xdg-shell/xdg-shell.xml' -print -quit)
[[ -n "$xdg_shell_xml" ]] || {
  echo "matching Buildroot wayland-protocols XML is missing: stable/xdg-shell/xdg-shell.xml" >&2
  exit 68
}
protocols_dir=$(cd -- "$(dirname -- "$xdg_shell_xml")/../.." && pwd)
[[ -f "$protocols_dir/unstable/xdg-decoration/xdg-decoration-unstable-v1.xml" ]] || {
  echo "matching Buildroot wayland-protocols XML is missing: unstable/xdg-decoration/xdg-decoration-unstable-v1.xml" >&2
  exit 69
}

build_root=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_root"; }
trap cleanup EXIT
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"

"$TDVP_K230_CMAKE" -S "$source_root" -B "$build_root" -G Ninja \
  -DCMAKE_MAKE_PROGRAM="$TDVP_K230_NINJA" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_PREFIX_PATH="$TDVP_FEED_STAGING_ROOT/usr;$TDVP_K230_WAYLAND_SDK_OVERLAY" \
  -DCMAKE_LIBRARY_PATH="$TDVP_FEED_STAGING_ROOT/usr/lib;$TDVP_K230_WAYLAND_SDK_OVERLAY/lib" \
  -DCMAKE_SKIP_RPATH=ON \
  -DBUILD_TESTING=OFF \
  -DLOFIBOX_BUILD_DEVICE=OFF \
  -DLOFIBOX_BUILD_TUI=OFF \
  -DLOFIBOX_BUILD_WEBUI=OFF \
  -DLOFIBOX_BUILD_WAYLAND=ON \
  -DLOFIBOX_BUILD_WIDGET=OFF \
  -DLOFIBOX_BUILD_X11=OFF \
  -DLOFIBOX_INSTALL_DOCUMENTATION=OFF \
  -DLOFIBOX_INSTALL_LAUNCHER=ON \
  -DLOFIBOX_WAYLAND_SCANNER_EXECUTABLE="$scanner" \
  -DLOFIBOX_WAYLAND_PROTOCOLS_DIR="$protocols_dir" \
  -DFREETYPE_INCLUDE_DIR_ft2build="$TDVP_K230_WAYLAND_SDK_OVERLAY/include" \
  -DFREETYPE_INCLUDE_DIR_freetype2="$TDVP_K230_WAYLAND_SDK_OVERLAY/include" \
  -DFREETYPE_LIBRARY="$TDVP_K230_WAYLAND_SDK_OVERLAY/lib/libfreetype.so"

"$TDVP_K230_CMAKE" --build "$build_root" --target lofibox_zero_wayland --parallel
"$TDVP_K230_STRIP" --strip-unneeded "$build_root/lofibox-wayland"
DESTDIR="$payload_dir" "$TDVP_K230_CMAKE" --install "$build_root"
install -Dm 0644 "$source_root/LICENSE" \
  "$payload_dir/usr/share/licenses/$PACKAGE/LICENSE"

echo "LoFiBox Wayland application payload ready: $payload_dir"
