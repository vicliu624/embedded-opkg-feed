#!/usr/bin/env bash
# Build the TDVP GBA frontend against the release-local shared runtime.  SDL2
# and mGBA are never bundled here: their independent feed packages are built
# once first and exposed through TDVP_FEED_STAGING_ROOT.
set -Eeuo pipefail
IFS=$'\n\t'

# A recipe can opt into reusing a byte-identical, SHA-256-pinned payload for a
# metadata-only feed republish. New source revisions intentionally omit those
# variables and always execute the audited cross-build below.
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
# shellcheck source=/dev/null
source "$package_dir/package.env"
if [[ "${TDVP_REUSE_PUBLISHED_PAYLOADS:-1}" == 1 && -n "${REUSE_IPK_URL:-}" && -n "${REUSE_IPK_SHA256:-}" ]]; then
  exec "$feed_root/scripts/reuse-published-ipk-payload.sh" "$package_dir"
fi

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "tdvp-gba does not support platform: $2" >&2; exit 65; }

# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$feed_root/scripts/tdvp-k230-sdk.sh"

source_root=${TDVP_GBA_SOURCE_DIR:-"$feed_root/../cardputer-zero-gameboy-emulator"}
source_root=$(tdvp_verify_git_source "$source_root" "$SOURCE_REPOSITORY" "$SOURCE_REVISION")
tdvp_require_k230_sdk "$4"
tdvp_require_wayland_sdk_overlay
tdvp_prepare_pkg_config

build_root=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_root"; }
trap cleanup EXIT
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"

(
  cd -- "$build_root"
  "$TDVP_K230_CMAKE" -G Ninja -DCMAKE_MAKE_PROGRAM="$TDVP_K230_NINJA" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_FLAGS_RELEASE='-O2 -g0 -D_FORTIFY_SOURCE=1 -fno-shrink-wrap' \
    -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
    -DCMAKE_PREFIX_PATH="$TDVP_FEED_STAGING_ROOT/usr" \
    -DCMAKE_LIBRARY_PATH="$TDVP_FEED_STAGING_ROOT/usr/lib;$TDVP_K230_WAYLAND_SDK_OVERLAY/lib" \
    -DCMAKE_SKIP_RPATH=ON \
    -DBUILD_TESTING=OFF \
    -DCZ_GBA_FETCH_SDL2=OFF -DCZ_GBA_BUNDLE_SDL2=OFF \
    -DCZ_GBA_PREFER_BUNDLED_SDL2=OFF \
    -DCZ_GBA_SDL2_ROOT="$TDVP_FEED_STAGING_ROOT/usr" \
    -DCZ_GBA_USE_SYSTEM_MGBA=ON -DCZ_GBA_BUNDLE_MGBA=OFF \
    -DCZ_GBA_MGBA_ROOT="$TDVP_FEED_STAGING_ROOT/usr" \
    -DCZ_GBA_REQUIRE_K230_DRM=ON \
    -DCZ_GBA_REQUIRE_K230_WAYLAND_SHM=ON \
    -DCZ_GBA_TDVP_WAYLAND_SDK_OVERLAY="$TDVP_K230_WAYLAND_SDK_OVERLAY" \
    -DALSA_INCLUDE_DIR="$TDVP_K230_WAYLAND_SDK_OVERLAY/include" \
    -DALSA_LIBRARY="$TDVP_K230_WAYLAND_SDK_OVERLAY/lib/libasound.so" \
    "$source_root"
)
"$TDVP_K230_CMAKE" --build "$build_root" --target cardputer-zero-gba --parallel
"$TDVP_K230_STRIP" --strip-unneeded "$build_root/cardputer-zero-gba"

# This package is the first consumer of the feed's shared-runtime contract.
# Do not merely trust CMake options: reject a release if a future project
# change silently falls back to statically linking bundled SDL2 or mGBA.
require_dynamic_soname() {
  local soname=$1
  "$TDVP_K230_READELF" -d "$build_root/cardputer-zero-gba" | \
    grep -Fq "Shared library: [$soname]" || {
      echo "tdvp-gba is missing required dynamic dependency: $soname" >&2
      exit 66
    }
}
require_dynamic_soname 'libSDL2-2.0.so.0'
require_dynamic_soname 'libmgba.so.0.10'

install -Dm 0755 "$build_root/cardputer-zero-gba" "$payload_dir/opt/tdvp-gba/cardputer-zero-gba"
install -Dm 0755 "$source_root/packaging/tdvp-k230/tdvp-gba" "$payload_dir/usr/bin/tdvp-gba"
install -Dm 0644 "$source_root/packaging/tdvp-k230/tdvp-gba.desktop" \
  "$payload_dir/usr/share/applications/tdvp-gba.desktop"
install -Dm 0644 "$source_root/assets/icons/cardputer-zero-gba-128.png" \
  "$payload_dir/usr/share/icons/hicolor/128x128/apps/tdvp-gba.png"
install -Dm 0644 "$source_root/README.md" "$payload_dir/usr/share/doc/tdvp-gba/README.md"
install -Dm 0644 "$source_root/LICENSE" "$payload_dir/usr/share/doc/tdvp-gba/LICENSE"
echo "tdvp-gba payload ready: $payload_dir"
