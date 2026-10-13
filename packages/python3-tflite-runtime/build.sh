#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# == 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk=$(realpath -e -- "$4")
stage=$(realpath -e -- "${TDVP_FEED_STAGING_ROOT:?}")
source "$repo_root/scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/native-cmake-input.sh"
source "$repo_root/support/elf-runtime-policy.sh"
for input in usr/lib/libtensorflow-lite.so usr/lib/libpython3.13.so usr/include/python3.13/Python.h usr/include/pybind11/pybind11.h usr/lib/python3.13/site-packages/numpy/_core/include/numpy/arrayobject.h; do
  [[ -f "$stage/$input" ]] || { echo "Missing declared TFLite Python development input: $input" >&2; exit 65; }
done
source "$repo_root/packages/libtensorflow-lite/source.lock"
core_source_sha=$SOURCE_ARTIFACT_1_SHA256
source "$package_dir/source.lock"
[[ "$SOURCE_ARTIFACT_1_SHA256" == "$core_source_sha" ]] || exit 66
native=${TDVP_NATIVE_CMAKE_CACHE_ROOT:-"$stage/.tdvp-native"}
tdvp_prepare_native_cmake_input "$repo_root/packages/libflatbuffers" "$native/flatbuffers" bin/flatc \
  -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=ON \
  -DFLATBUFFERS_BUILD_FLATHASH=OFF -DFLATBUFFERS_BUILD_SHAREDLIB=OFF
key=$({
  sha256sum "$sdk/tdvp-sdk-manifest.json" "$package_dir/build.sh" "$package_dir/package.env" "$package_dir/source.lock" "$package_dir/files/METADATA" "$repo_root/support/python-tflite-binding/"* "$repo_root/support/tflite-regenerate-schemas.sh"
  sha256sum "$repo_root/packages/pybind11-dev/source.lock" "$repo_root/packages/python3-numpy/source.lock"
  for input in python3.13 pybind11 absl tensorflow flatbuffers; do find "$stage/usr/include/$input" -type f -print0; done | sort -z | xargs -0 sha256sum
  find "$stage/usr/lib/python3.13/site-packages/numpy/_core/include" -type f -print0 | sort -z | xargs -0 sha256sum
  sha256sum "$stage/usr/lib/libtensorflow-lite.so" "$stage/usr/lib/libpython3.13.so" "$stage/usr/lib/"libabsl*.so* "$native/flatbuffers/bin/flatc"
} | sha256sum | cut -d' ' -f1)
cache=${TDVP_INFERENCE_BUILD_CACHE_ROOT:-"$stage/.tdvp-inference-build"}
[[ ! -L "$cache" ]] || exit 67
work="$cache/tflite-python-$key"
[[ ! -L "$work" ]] || exit 67
mkdir -p "$work/source" "$work/wrapper"
if [[ ! -f "$work/.prepared" ]]; then
  source_root=$(tdvp_unpack_locked_source_archive "$package_dir" "$work/source")
  bash "$repo_root/support/tflite-regenerate-schemas.sh" "$source_root" "$native/flatbuffers/bin/flatc"
  cp "$source_root/tensorflow/lite/python/interpreter_wrapper/interpreter_wrapper.cc" "$work/wrapper/"
  patch -d "$work/wrapper" -p1 --fuzz=0 --forward --dry-run < "$repo_root/support/python-tflite-binding/0001-reject-unavailable-xnnpack-option.patch"
  patch -d "$work/wrapper" -p1 --fuzz=0 --forward < "$repo_root/support/python-tflite-binding/0001-reject-unavailable-xnnpack-option.patch"
  printf '%s\n' "$source_root" > "$work/.prepared"
fi
source_root=$(<"$work/.prepared")
[[ "$source_root" == "$work/source/"* && -f "$source_root/LICENSE" ]] || exit 68
unset CMAKE_TOOLCHAIN_FILE
cmake -S "$repo_root/support/python-tflite-binding" -B "$work/build" -G Ninja \
  -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 -DCMAKE_SYSROOT="$sdk/sysroot" \
  -DCMAKE_CXX_COMPILER="$sdk/bin/riscv64-unknown-linux-gnu-g++" \
  -DCMAKE_CXX_FLAGS='-O1 -march=rv64imafdc_zicsr_zifencei -mabi=lp64d' \
  -DTF_SOURCE_ROOT="$source_root" -DWRAPPER_SOURCE_ROOT="$work/wrapper" \
  -DTF_STAGE_ROOT="$stage" -DPYTHON_STAGE_ROOT="$stage"
cmake --build "$work/build" --parallel "${TDVP_JOBS:-4}"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
site="$payload/usr/lib/python3.13/site-packages"
mkdir -p "$site/tflite_runtime" "$site/tflite_runtime-2.18.0.dist-info"
cp "$work/build/_pywrap_tensorflow_interpreter_wrapper.so" "$source_root/tensorflow/lite/python/interpreter.py" "$repo_root/support/python-tflite-binding/__init__.py" "$site/tflite_runtime/"
cp "$source_root/tensorflow/lite/python/metrics/metrics_interface.py" "$source_root/tensorflow/lite/python/metrics/metrics_portable.py" "$site/tflite_runtime/"
install -m 644 "$package_dir/files/METADATA" "$site/tflite_runtime-2.18.0.dist-info/METADATA"
install -m 644 "$source_root/LICENSE" "$site/tflite_runtime-2.18.0.dist-info/LICENSE"
mkdir -p "$work/notice-source/pybind11" "$work/notice-source/numpy" "$site/tflite_runtime-2.18.0.dist-info/licenses"
pybind_source=$(tdvp_unpack_locked_source_archive "$repo_root/packages/pybind11-dev" "$work/notice-source/pybind11")
numpy_source=$(tdvp_unpack_locked_source_archive "$repo_root/packages/python3-numpy" "$work/notice-source/numpy")
install -m 644 "$pybind_source/LICENSE" "$site/tflite_runtime-2.18.0.dist-info/licenses/pybind11-LICENSE"
install -m 644 "$numpy_source/LICENSE.txt" "$site/tflite_runtime-2.18.0.dist-info/licenses/numpy-LICENSE.txt"
python3 "$repo_root/scripts/verify-published-sdk-payload.py" "$sdk" "$payload"
printf 'TFLite Python source-built payload: %s\n' "$payload"
