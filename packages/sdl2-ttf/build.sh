#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

if [[ "${TDVP_REUSE_PUBLISHED_PAYLOADS:-1}" == 1 ]]; then
  package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  feed_root=$(cd -- "$package_dir/../.." && pwd)
  exec "$feed_root/scripts/reuse-published-ipk-payload.sh" "$package_dir"
fi

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "sdl2-ttf does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
# shellcheck source=/dev/null
source "$package_dir/package.env"
# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$feed_root/scripts/tdvp-k230-sdk.sh"

temporary_source=
source_root=${TDVP_SDL2_TTF_SOURCE_DIR:-}
if [[ -z "$source_root" ]]; then
  temporary_source=$(mktemp -d)
  source_root="$temporary_source/source"
  git clone --filter=blob:none "$SOURCE_REPOSITORY" "$source_root"
  git -C "$source_root" checkout --detach "$SOURCE_REVISION"
fi
source_root=$(tdvp_verify_git_source "$source_root" "$SOURCE_REPOSITORY" "$SOURCE_REVISION")
tdvp_require_k230_sdk "$4"
tdvp_require_wayland_sdk_overlay
tdvp_prepare_pkg_config

build_root=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_root" "$temporary_source"; }
trap cleanup EXIT
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"

(
  cd -- "$build_root"
  # SDL_ttf 2.22's own FindPrivateSDL2 module does not consult SDL2's
  # package-config file.  Pin its two cache variables to the library and
  # headers installed by this very feed-build graph; do not let CMake fall
  # back to a host SDL2 or request a static/bundled copy.
  "$TDVP_K230_CMAKE" -G Ninja -DCMAKE_MAKE_PROGRAM="$TDVP_K230_NINJA" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
    -DCMAKE_PREFIX_PATH="$TDVP_FEED_STAGING_ROOT/usr" \
    -DSDL2_LIBRARY="$TDVP_FEED_STAGING_ROOT/usr/lib/libSDL2.so" \
    -DSDL2_INCLUDE_DIR="$TDVP_FEED_STAGING_ROOT/usr/include/SDL2" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DSDL2TTF_VENDORED=OFF -DSDL2TTF_SAMPLES=OFF -DSDL2TTF_TESTS=OFF \
    -DCMAKE_SKIP_RPATH=ON \
    "$source_root"
)
"$TDVP_K230_CMAKE" --build "$build_root" --parallel
DESTDIR="$TDVP_FEED_STAGING_ROOT" "$TDVP_K230_CMAKE" --install "$build_root"
tdvp_copy_runtime_library "$TDVP_FEED_STAGING_ROOT" "$payload_dir" 'libSDL2_ttf-2.0.so.*'
install -Dm 0644 "$source_root/LICENSE.txt" "$payload_dir/usr/share/licenses/sdl2-ttf/LICENSE.txt"
echo "sdl2-ttf runtime payload ready: $payload_dir"
