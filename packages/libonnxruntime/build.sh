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
protobuf_native=${TDVP_NATIVE_PROTOBUF_ROOT:-"$TDVP_FEED_STAGING_ROOT/.tdvp-native/serialization"}
flatbuffers_package=$(cd -- "$package_dir/../libflatbuffers" && pwd)
protobuf_package=$(cd -- "$package_dir/../libprotobuf" && pwd)
abseil_package=$(cd -- "$package_dir/../libabseil-cpp" && pwd)
tdvp_prepare_native_cmake_input "$flatbuffers_package" "$native_root/flatbuffers" bin/flatc \
  -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=ON \
  -DFLATBUFFERS_BUILD_FLATHASH=OFF -DFLATBUFFERS_BUILD_SHAREDLIB=OFF
# Imported target staging does not carry native generators. Prepare protoc's
# host-only dependency even when the target protobuf provider was reused.
tdvp_prepare_native_cmake_input "$abseil_package" "$protobuf_native/abseil" \
  lib/cmake/absl/abslConfig.cmake -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF \
  -DABSL_PROPAGATE_CXX_STD=ON
tdvp_prepare_native_cmake_input "$protobuf_package" "$protobuf_native/protobuf" bin/protoc \
  -DCMAKE_PREFIX_PATH="$protobuf_native/abseil" -Dprotobuf_ABSL_PROVIDER=package \
  -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF \
  -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_WITH_ZLIB=OFF
[[ "$("$protobuf_native/protobuf/bin/protoc" --version)" == 'libprotoc 29.3' ]] || exit 66
# Fingerprint declared development providers, not every unrelated package
# staged in a batch. The immutable SDK manifest binds its own development files.
development_dirs=(
  usr/include/absl usr/include/re2 usr/include/google usr/include/date
  usr/include/flatbuffers usr/include/onnx usr/include/eigen3 usr/include/gsl
  usr/include/safeint usr/include/boost/mp11 usr/include/nlohmann
  usr/lib/cmake/absl usr/lib/cmake/re2 usr/lib/cmake/protobuf
  usr/lib/cmake/utf8_range usr/lib/cmake/date usr/lib/cmake/flatbuffers
  usr/lib/cmake/ONNX usr/lib/cmake/boost_mp11 usr/share/eigen3/cmake
  usr/share/cmake/Microsoft.GSL usr/share/cmake/nlohmann_json
)
for input in "${development_dirs[@]}"; do
  [[ -d "$TDVP_FEED_STAGING_ROOT/$input" ]] || { echo "missing development export: $input" >&2; exit 67; }
done
key=$({
  sha256sum "$package_dir/source.lock" "$package_dir/package.env" \
    "$sdk_root/tdvp-sdk-manifest.json" "$package_dir/build.sh" \
    "$repo_root/support/onnxruntime-regenerate-schemas.sh" \
    "$repo_root/support/onnxruntime-import-platform-dependencies.cmake" "$package_dir/patches/"*.patch
  for input in "${development_dirs[@]}"; do
    find "$TDVP_FEED_STAGING_ROOT/$input" -type f -print0
  done | sort -z | xargs -0 sha256sum
  sha256sum "$TDVP_FEED_STAGING_ROOT/usr/include/boost/mp11.hpp"
  find "$TDVP_FEED_STAGING_ROOT/usr/include" -maxdepth 1 -type f \
    -name 'utf8*.h' -print0 | sort -z | xargs -0 -r sha256sum
  find "$TDVP_FEED_STAGING_ROOT/usr/lib" -maxdepth 1 -type f \
    \( -name 'libabsl*.so*' -o -name 'libre2.so*' -o -name 'libprotobuf*.so*' \
       -o -name 'libutf8*.so*' -o -name 'libupb*.so*' -o -name 'libdate-tz.so*' \
       -o -name 'libflatbuffers.so*' -o -name 'libonnx*.so*' \) \
    ! -name 'libonnxruntime*.so*' -print0 | sort -z | xargs -0 sha256sum
  printf '%s\n' "$sdk_root"
} | sha256sum | cut -d' ' -f1)
cache_root=${TDVP_INFERENCE_BUILD_CACHE_ROOT:-"$TDVP_FEED_STAGING_ROOT/.tdvp-inference-build"}
[[ ! -L "$cache_root" ]] || exit 68
mkdir -p "$cache_root"
work="$cache_root/onnxruntime-$key"
[[ ! -L "$work" ]] || exit 68
mkdir -p "$work/source" "$work/sysroot"
if [[ ! -f "$work/.prepared" ]]; then
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  for source_patch in "$package_dir/patches/"*.patch; do
    patch --directory="$source_root" -p1 --fuzz=0 --forward --dry-run < "$source_patch"
    patch --directory="$source_root" -p1 --fuzz=0 --forward < "$source_patch"
  done
  bash "$repo_root/support/onnxruntime-regenerate-schemas.sh" "$source_root" "$native_root/flatbuffers/bin/flatc"
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  cp -a --reflink=auto "$TDVP_FEED_STAGING_ROOT/usr/." "$work/sysroot/usr/"
  printf '%s\n' "$source_root" > "$work/.prepared"
fi
source_root=$(<"$work/.prepared")
[[ "$source_root" == "$work/source/"* && -f "$source_root/LICENSE" ]] || exit 69
source "$sdk_root/environment-setup.sh"
unset CMAKE_TOOLCHAIN_FILE
sysroot="$work/sysroot"
export PKG_CONFIG_SYSROOT_DIR="$sysroot" PKG_CONFIG_LIBDIR="$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig" PKG_CONFIG_PATH=
cmake -S "$source_root/cmake" -B "$work/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE= -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
  -DCMAKE_SYSROOT="$sysroot" -DCMAKE_FIND_ROOT_PATH="$sysroot" \
  -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON -DCMAKE_INCLUDE_PATH="$sysroot/usr/include/safeint" \
  -DCMAKE_PROJECT_INCLUDE="$repo_root/support/onnxruntime-import-platform-dependencies.cmake" \
  -DCMAKE_C_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-gcc" \
  -DCMAKE_CXX_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-g++" \
  -DCMAKE_C_FLAGS="$CFLAGS -fPIC -O1" -DCMAKE_CXX_FLAGS="$CXXFLAGS -fPIC -O1" \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$sysroot/usr/lib" \
  -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG -DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG \
  -DCMAKE_SKIP_RPATH=ON -DTDVP_NATIVE_FLATC="$native_root/flatbuffers/bin/flatc" \
  -DONNX_CUSTOM_PROTOC_EXECUTABLE="$protobuf_native/protobuf/bin/protoc" \
  -DFETCHCONTENT_TRY_FIND_PACKAGE_MODE=ALWAYS -DFETCHCONTENT_FULLY_DISCONNECTED=ON \
  -Donnxruntime_BUILD_SHARED_LIB=ON -Donnxruntime_BUILD_UNIT_TESTS=OFF \
  -Donnxruntime_USE_FULL_PROTOBUF=ON -Donnxruntime_DISABLE_CONTRIB_OPS=OFF \
  -Donnxruntime_ENABLE_PYTHON=OFF -Donnxruntime_DISABLE_RTTI=OFF -Donnxruntime_USE_CUDA=OFF \
  -Donnxruntime_USE_XNNPACK=OFF -Donnxruntime_USE_MIMALLOC=OFF
cmake --build "$work/build" --target onnxruntime onnxruntime_providers_shared --parallel "${TDVP_JOBS:-4}"
DESTDIR="$work/install" cmake --install "$work/build"
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p "$payload_dir/usr/lib"
cp -a "$work/install/usr/lib/"libonnxruntime*.so* "$payload_dir/usr/lib/"
tdvp_assert_direct_archive_elfs "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" \
  "$sdk_root/bin/riscv64-unknown-linux-gnu-strip" "$payload_dir"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr"
cp -a "$work/install/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload_dir"
# The Python binding consumes exactly this ABI-bound core cache. This record
# is build metadata, never executable shell input or part of the runtime IPK.
python3 - "$work" "$TDVP_FEED_STAGING_ROOT/.tdvp-onnxruntime-core.json" "$sdk_root/tdvp-sdk-manifest.json" <<'PY'
import hashlib, json, pathlib, sys
work, destination, manifest = map(pathlib.Path, sys.argv[1:])
record = {
    'schema': 1,
    'work': str(work.resolve()),
    'sdk_manifest_sha256': hashlib.sha256(manifest.read_bytes()).hexdigest(),
    'rtti': True,
}
destination.write_text(json.dumps(record, sort_keys=True) + '\n')
PY
development="$TDVP_FEED_STAGING_ROOT/usr/share/tdvp-build/onnxruntime"
if [[ -e "$development" || -L "$development" ]]; then
  python3 "$repo_root/scripts/onnxruntime-development-export.py" verify "$development" \
    --sdk "$sdk_root" --package "$package_dir"
else
  python3 "$repo_root/scripts/onnxruntime-development-export.py" export "$development" \
    --sdk "$sdk_root" --package "$package_dir" \
    --core-record "$TDVP_FEED_STAGING_ROOT/.tdvp-onnxruntime-core.json"
fi
printf '%s\n' "ONNX Runtime source payload ready: $payload_dir"
