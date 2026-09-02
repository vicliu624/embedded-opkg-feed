#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

# A composable r3 republish changes metadata only.  Reuse the immutable r2
# payload by default so SDL2 is built once and shared by all future leaves.
# Set TDVP_REUSE_PUBLISHED_PAYLOADS=0 only for an intentional source rebuild.
if [[ "${TDVP_REUSE_PUBLISHED_PAYLOADS:-1}" == 1 ]]; then
  package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  feed_root=$(cd -- "$package_dir/../.." && pwd)
  exec "$feed_root/scripts/reuse-published-ipk-payload.sh" "$package_dir"
fi

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
patched_source=$(mktemp -d)
payload_dir="$package_dir/root"
cleanup() { rm -rf -- "$build_root" "$patched_source"; }
trap cleanup EXIT
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"

# The feed owns the K230 buffering policy without forking SDL2. Materialize an
# exact pinned checkout in a disposable directory, apply the reviewed
# downstream patch there, and leave the source-locked checkout untouched for
# the later application recipes in this same release.
rm -rf -- "$patched_source"
# The source and feed can be checked out on Windows while the cross build runs
# in WSL.  Force the disposable clone and its reviewed patch to LF before
# applying it, so CRLF worktrees cannot change the patch context or the SDL
# source that is actually compiled.
git -c core.autocrlf=false clone --no-checkout "$source_root" "$patched_source"
git -C "$patched_source" -c core.autocrlf=false checkout --detach "$SOURCE_REVISION"
pulseaudio_patch="$build_root/0001-pulseaudio-add-opt-in-stream-buffer.patch"
sed 's/\r$//' "$package_dir/patches/0001-pulseaudio-add-opt-in-stream-buffer.patch" >"$pulseaudio_patch"
git -C "$patched_source" apply --check "$pulseaudio_patch"
git -C "$patched_source" apply "$pulseaudio_patch"

# SDL's CMake helper derives the dlopen name from the file passed to it rather
# than reading ELF DT_SONAME. Some SDK bridges retain the real target object
# only under libpulse.so (the development-link name). Materialise a disposable
# file using its verified SONAME so SDL records the target runtime name, never
# the overlay's development filename, in SDL_config.h.
pulse_soname=$("$TDVP_K230_READELF" -d "$TDVP_K230_WAYLAND_SDK_OVERLAY/lib/libpulse.so" | \
  sed -n 's/.*SONAME.*\[\(libpulse\.so\.[0-9][0-9.]*\)\].*/\1/p' | head -n 1)
[[ -n "$pulse_soname" ]] || {
  echo 'could not read a versioned libpulse DT_SONAME from the TDVP SDK overlay' >&2
  exit 66
}
pulse_loader_probe="$build_root/$pulse_soname"
cp -L -- "$TDVP_K230_WAYLAND_SDK_OVERLAY/lib/libpulse.so" "$pulse_loader_probe"

(
  cd -- "$build_root"
  # Overlay .pc files use a normal /usr prefix. PKG_CONFIG_SYSROOT_DIR
  # intentionally rewrites that prefix to the immutable SDK sysroot, so
  # make this separate development overlay explicit to both the compiler
  # and SDL's FindLibraryAndSONAME dynamic-loader probe.
  "$TDVP_K230_CMAKE" -G Ninja -DCMAKE_MAKE_PROGRAM="$TDVP_K230_NINJA" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TDVP_K230_TOOLCHAIN_FILE" \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_C_FLAGS="-I$TDVP_K230_WAYLAND_SDK_OVERLAY/include" \
    -DCMAKE_LIBRARY_PATH="$TDVP_K230_WAYLAND_SDK_OVERLAY/lib" \
    -DPULSE_LIB="$pulse_loader_probe" \
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
    "$patched_source"
)
"$TDVP_K230_CMAKE" --build "$build_root" --parallel
DESTDIR="$TDVP_FEED_STAGING_ROOT" "$TDVP_K230_CMAKE" --install "$build_root"
tdvp_copy_runtime_library "$TDVP_FEED_STAGING_ROOT" "$payload_dir" 'libSDL2-2.0.so.*'
install -Dm 0644 "$source_root/LICENSE.txt" "$payload_dir/usr/share/licenses/sdl2/LICENSE.txt"
echo "sdl2 runtime payload ready: $payload_dir"
