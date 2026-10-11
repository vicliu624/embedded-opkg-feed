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
stage=${TDVP_FEED_STAGING_ROOT:?}
native_root=${TDVP_NATIVE_PROTOBUF_ROOT:-"$stage/.tdvp-native/serialization"}
protobuf_package=$(cd -- "$package_dir/../libprotobuf" && pwd)
tdvp_prepare_native_cmake_input "$package_dir/../libabseil-cpp" "$native_root/abseil" \
  lib/cmake/absl/abslConfig.cmake -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF \
  -DABSL_PROPAGATE_CXX_STD=ON
tdvp_prepare_native_cmake_input "$protobuf_package" "$native_root/protobuf" bin/protoc \
  -DCMAKE_PREFIX_PATH="$native_root/abseil" -Dprotobuf_ABSL_PROVIDER=package \
  -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF \
  -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_WITH_ZLIB=OFF
[[ "$("$native_root/protobuf/bin/protoc" --version)" == 'libprotoc 29.3' ]] || exit 65
inputs=(usr/include/onnx usr/include/google usr/include/absl usr/include/python3.13
        usr/include/pybind11 usr/lib/cmake/ONNX usr/lib/cmake/protobuf usr/lib/cmake/absl
        usr/lib/cmake/utf8_range)
for input in "${inputs[@]}"; do [[ -d "$stage/$input" ]] || { echo "missing development input: $input" >&2; exit 66; }; done
key=$({
  sha256sum "$sdk_root/tdvp-sdk-manifest.json" "$package_dir/source.lock" "$package_dir/build.sh" \
    "$package_dir/package.env" "$repo_root/support/python-onnx-binding/CMakeLists.txt" \
    "$repo_root/support/python-onnx-binding/version.py"
  for input in "${inputs[@]}"; do find "$stage/$input" -type f -print0; done | sort -z | xargs -0 sha256sum
  find "$stage/usr/lib" -maxdepth 1 -type f \( -name 'libonnx*.so*' -o -name 'libprotobuf*.so*' -o -name 'libabsl*.so*' \) \
    ! -name 'libonnxruntime*.so*' -print0 | sort -z | xargs -0 sha256sum
} | sha256sum | cut -d' ' -f1)
cache_root=${TDVP_INFERENCE_BUILD_CACHE_ROOT:-"$stage/.tdvp-inference-build"}
[[ ! -L "$cache_root" ]] || exit 67
work="$cache_root/onnx-python-$key"
[[ ! -L "$work" ]] || exit 67
mkdir -p "$work/source" "$work/sysroot"
if [[ ! -f "$work/.prepared" ]]; then
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  python3 "$source_root/onnx/gen_proto.py" --ml
  "$native_root/protobuf/bin/protoc" --proto_path="$source_root" --python_out="$source_root" \
    "$source_root/onnx/onnx-ml.proto" "$source_root/onnx/onnx-operators-ml.proto" "$source_root/onnx/onnx-data.proto"
  cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
  cp -a --reflink=auto "$stage/usr/." "$work/sysroot/usr/"
  printf '%s\n' "$source_root" > "$work/.prepared"
fi
source_root=$(<"$work/.prepared")
[[ "$source_root" == "$work/source/"* && -f "$source_root/onnx/cpp2py_export.cc" ]] || exit 68
unset CMAKE_TOOLCHAIN_FILE
cmake -S "$repo_root/support/python-onnx-binding" -B "$work/build" -G Ninja \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 -DCMAKE_SYSROOT="$work/sysroot" \
  -DCMAKE_FIND_ROOT_PATH="$work/sysroot" -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
  -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
  -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY -DCMAKE_SKIP_RPATH=ON \
  -DCMAKE_CXX_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-g++" -DCMAKE_CXX_FLAGS=-O1 \
  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$work/sysroot/usr/lib" \
  -DONNX_SOURCE_ROOT="$source_root" -DTDVP_TARGET_PYTHON_INCLUDE="$work/sysroot/usr/include/python3.13" \
  -DTDVP_PYBIND11_INCLUDE="$work/sysroot/usr/include"
cmake --build "$work/build" --parallel "${TDVP_JOBS:-4}"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
site="$payload/usr/lib/python3.13/site-packages"
mkdir -p "$site/onnx" "$site/onnx-1.17.0.dist-info"
# Project upstream runtime Python/data files without C++ implementation sources.
python3 - "$source_root/onnx" "$site/onnx" <<'PY'
import pathlib, shutil, sys
source, destination = map(pathlib.Path, sys.argv[1:])
for path in source.rglob('*'):
    if path.is_file() and path.suffix in {'.py', '.pyi', '.proto', '.proto3', '.onnx', '.pb', '.json'}:
        target = destination / path.relative_to(source)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
PY
cp "$work/build/onnx_cpp2py_export.so" "$site/onnx/"
cp "$repo_root/support/python-onnx-binding/version.py" "$site/onnx/version.py"
cp "$package_dir/files/METADATA" "$site/onnx-1.17.0.dist-info/"
for runtime_patch in "$package_dir/patches/"*.patch; do
  patch --directory="$site" -p1 --fuzz=0 --forward --dry-run < "$runtime_patch"
  patch --directory="$site" -p1 --fuzz=0 --forward < "$runtime_patch"
done
install -m 0644 "$source_root/LICENSE" "$site/onnx-1.17.0.dist-info/LICENSE"
tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" "$site/onnx/onnx_cpp2py_export.so"
python3 "$repo_root/scripts/verify-published-sdk-payload.py" "$sdk_root" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload"
printf '%s\n' "Python ONNX public-provider payload ready: $payload"
