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
[[ "$2" == tdvp-k230-r1 ]] || { echo "libmgba does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
# shellcheck source=/dev/null
source "$package_dir/package.env"
# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$feed_root/scripts/tdvp-k230-sdk.sh"
# shellcheck source=../../support/source-archive-library.sh
source "$feed_root/support/source-archive-library.sh"

tdvp_require_k230_sdk "$4"

build_root=$(mktemp -d)
source_tree=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_root" "$source_tree"; }
trap cleanup EXIT
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"
source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$source_tree")

(
  cd -- "$build_root"
  "$TDVP_K230_CMAKE" -G Ninja -DCMAKE_MAKE_PROGRAM="$TDVP_K230_NINJA" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DM_CORE_GBA=ON -DM_CORE_GB=OFF \
    -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DBUILD_QT=OFF -DBUILD_SDL=OFF \
    -DBUILD_GL=OFF -DBUILD_GLES2=OFF -DBUILD_GLES3=OFF \
    -DBUILD_TEST=OFF -DBUILD_SUITE=OFF -DBUILD_CINEMA=OFF \
    -DBUILD_ROM_TEST=OFF -DBUILD_EXAMPLE=OFF -DBUILD_PYTHON=OFF \
    -DUSE_DEBUGGERS=OFF -DUSE_FFMPEG=OFF -DUSE_PNG=OFF -DUSE_ZLIB=OFF \
    -DUSE_MINIZIP=OFF -DUSE_LIBZIP=OFF -DUSE_SQLITE3=OFF -DUSE_ELF=OFF \
    -DUSE_LUA=OFF -DUSE_LZMA=OFF -DUSE_DISCORD_RPC=OFF -DENABLE_SCRIPTING=OFF \
    -DCMAKE_SKIP_RPATH=ON \
    "$source_root"
)
"$TDVP_K230_CMAKE" --build "$build_root" --parallel
DESTDIR="$TDVP_FEED_STAGING_ROOT" "$TDVP_K230_CMAKE" --install "$build_root"
tdvp_copy_runtime_library "$TDVP_FEED_STAGING_ROOT" "$payload_dir" 'libmgba.so.*'
install -Dm 0644 "$source_root/LICENSE" "$payload_dir/usr/share/licenses/libmgba/LICENSE"
echo "libmgba runtime payload ready: $payload_dir"
