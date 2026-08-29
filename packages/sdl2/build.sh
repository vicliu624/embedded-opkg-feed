#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "sdl2 does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
feed_root=$(cd -- "$package_dir/../.." && pwd)
# shellcheck source=/dev/null
source "$package_dir/package.env"
# shellcheck source=../../scripts/tdvp-k230-sdk.sh
source "$feed_root/scripts/tdvp-k230-sdk.sh"

source_root=${TDVP_SDL2_SOURCE_DIR:-"$feed_root/../cardputer-zero-gameboy-emulator/extern/SDL"}
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
    -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DSDL_SHARED=ON -DSDL_STATIC=OFF -DSDL_TEST=OFF \
    -DSDL_VIDEO=ON -DSDL_WAYLAND=ON -DSDL_WAYLAND_SHARED=ON \
    -DSDL_WAYLAND_LIBDECOR=OFF -DSDL_WAYLAND_QT_TOUCH=OFF \
    -DSDL_KMSDRM=OFF -DSDL_X11=OFF -DSDL_VIVANTE=OFF -DSDL_RPI=OFF \
    -DSDL_OPENGL=OFF -DSDL_OPENGLES=OFF -DSDL_VULKAN=OFF \
    -DSDL_DBUS=OFF -DSDL_IBUS=OFF -DSDL_HIDAPI=OFF \
    -DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF -DSDL_SENSOR=OFF \
    -DSDL_PULSEAUDIO=ON -DSDL_PULSEAUDIO_SHARED=ON \
    -DSDL_ALSA=ON -DSDL_ALSA_SHARED=ON -DSDL_SNDIO=OFF \
    -DCMAKE_SKIP_RPATH=ON \
    "$source_root"
)
"$TDVP_K230_CMAKE" --build "$build_root" --parallel
DESTDIR="$TDVP_FEED_STAGING_ROOT" "$TDVP_K230_CMAKE" --install "$build_root"
tdvp_copy_runtime_library "$TDVP_FEED_STAGING_ROOT" "$payload_dir" 'libSDL2-2.0.so.*'
install -Dm 0644 "$source_root/LICENSE.txt" "$payload_dir/usr/share/licenses/sdl2/LICENSE.txt"
echo "sdl2 runtime payload ready: $payload_dir"
