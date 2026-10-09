#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk_root=$(realpath -e -- "$4")
source "$package_dir/package.env"
source "$repo_root/scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/elf-runtime-policy.sh"
source "$repo_root/support/native-cmake-input.sh"
[[ -f "$sdk_root/tdvp-sdk-manifest.json" && -d ${TDVP_FEED_STAGING_ROOT:-} && ! -L $TDVP_FEED_STAGING_ROOT ]] || exit 65
native_root=${TDVP_NATIVE_CMAKE_CACHE_ROOT:-"$TDVP_FEED_STAGING_ROOT/.tdvp-native"}
flatbuffers_package=$(cd -- "$package_dir/../libflatbuffers" && pwd)
tdvp_prepare_native_cmake_input "$flatbuffers_package" "$native_root/flatbuffers" bin/flatc \
  -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=ON \
  -DFLATBUFFERS_BUILD_FLATHASH=OFF -DFLATBUFFERS_BUILD_SHAREDLIB=OFF
# Bind objects to actual development exports, source, helpers and SDK identity.
# Header-only upgrades invalidate consumers even if archive mtimes are older.
key=$({
  sha256sum "$package_dir/source.lock" "$sdk_root/tdvp-sdk-manifest.json" \
    "$repo_root/support/tflite-regenerate-schemas.sh" \
    "$repo_root/support/tflite-import-platform-dependencies.cmake" "$package_dir/build.sh"
  find "$TDVP_FEED_STAGING_ROOT/usr" \
    \( -path "$TDVP_FEED_STAGING_ROOT/usr/include/tensorflow" \
       -o -path "$TDVP_FEED_STAGING_ROOT/usr/lib/cmake/tensorflow-lite" \) -prune \
    -o -type f ! -name 'libtensorflow-lite.so*' -print0 | sort -z | xargs -0 sha256sum
  printf '%s\n' "$sdk_root"
} | sha256sum | cut -d' ' -f1)
cache_root=${TDVP_INFERENCE_BUILD_CACHE_ROOT:-"$TDVP_FEED_STAGING_ROOT/.tdvp-inference-build"}
[[ ! -L "$cache_root" ]] || exit 66
mkdir -p "$cache_root"
work="$cache_root/tflite-$key"
[[ ! -L "$work" ]] || exit 66
mkdir -p "$work/source" "$work/sysroot"
if [[ ! -f "$work/.prepared" ]]; then
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  bash "$repo_root/support/tflite-regenerate-schemas.sh" "$source_root" "$native_root/flatbuffers/bin/flatc"
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
  printf '%s\n' "$source_root" > "$work/.prepared"
fi
source_root=$(<"$work/.prepared")
[[ "$source_root" == "$work/source/"* && -f "$source_root/LICENSE" ]] || exit 67
source "$sdk_root/environment-setup.sh"
unset CMAKE_TOOLCHAIN_FILE
sysroot="$work/sysroot"
export PKG_CONFIG_SYSROOT_DIR="$sysroot" PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig" PKG_CONFIG_PATH=
cmake -S "$source_root/tensorflow/lite" -B "$work/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE= -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_SYSROOT="$sysroot" -DCMAKE_FIND_ROOT_PATH="$sysroot" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
  -DCMAKE_PROJECT_INCLUDE="$repo_root/support/tflite-import-platform-dependencies.cmake" \
  -DCMAKE_C_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
  -DCMAKE_CXX_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-g++" \
  -DCMAKE_C_FLAGS="$CFLAGS -fPIC -O1" -DCMAKE_CXX_FLAGS="$CXXFLAGS -fPIC -O1" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$sysroot/usr/lib" \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE= -DCMAKE_CXX_FLAGS_RELEASE= \
  -DCMAKE_SKIP_RPATH=ON -DBUILD_SHARED_LIBS=ON \
  -DTFLITE_ENABLE_INSTALL=ON -DTFLITE_ENABLE_XNNPACK=OFF \
  -DTFLITE_ENABLE_GPU=OFF -DTFLITE_ENABLE_NNAPI=OFF -DTFLITE_ENABLE_RUY=ON \
  -DTFLITE_HOST_TOOLS_DIR="$native_root/flatbuffers" -DSYSTEM_FARMHASH=ON \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
cmake --build "$work/build" --target tensorflow-lite --parallel "${TDVP_JOBS:-4}"
DESTDIR="$work/install" cmake --install "$work/build"
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib"
cp -a "$work/install/usr/lib/"libtensorflow-lite.so* "$payload_dir/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" \
  "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir"
printf '%s\n' "TensorFlow Lite source payload ready: $payload_dir"
