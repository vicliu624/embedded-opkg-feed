#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
sdk_root=$(realpath -e -- "$4")
stage=${TDVP_FEED_STAGING_ROOT:?}
source "$repo_root/scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$repo_root/support/source-archive-library.sh"
source "$repo_root/support/elf-runtime-policy.sh"
core="$stage/usr/share/tdvp-build/onnxruntime"
if [[ ! -e "$core" && ! -L "$core" ]]; then
  bash "$repo_root/packages/libonnxruntime/build.sh" --platform tdvp-k230-r1 --sdk-root "$sdk_root"
fi
python3 "$repo_root/scripts/onnxruntime-development-export.py" verify "$core" \
  --sdk "$sdk_root" --package "$repo_root/packages/libonnxruntime"
source_root="$core/source"
[[ -f "$source_root/LICENSE" ]] || exit 65
source "$package_dir/source.lock"
source "$repo_root/packages/libonnxruntime/source.lock"
# Both package recipes must use the same source bytes, not only a version label.
core_source_sha=$SOURCE_ARTIFACT_1_SHA256
source "$package_dir/source.lock"
[[ "$SOURCE_ARTIFACT_1_SHA256" == "$core_source_sha" ]] || exit 66
numpy_include="$stage/usr/lib/python3.13/site-packages/numpy/_core/include"
inputs=("$stage/usr/include/python3.13" "$stage/usr/include/pybind11" "$numpy_include")
for input in "${inputs[@]}"; do [[ -d "$input" ]] || { echo "Missing Python development input: $input" >&2; exit 67; }; done
key=$({
 sha256sum "$sdk_root/tdvp-sdk-manifest.json" "$package_dir/build.sh" "$package_dir/source.lock" \
   "$package_dir/package.env" "$package_dir/files/METADATA" \
   "$repo_root/support/python-onnxruntime-binding/"* "$core/build/CMakeCache.txt"
 for input in "${inputs[@]}"; do find "$input" -type f -print0; done | sort -z | xargs -0 sha256sum
 find "$core/build" -maxdepth 1 -type f -name 'libonnxruntime_*.a' -print0 | sort -z | xargs -0 sha256sum
} | sha256sum | cut -d' ' -f1)
cache=${TDVP_INFERENCE_BUILD_CACHE_ROOT:-"$stage/.tdvp-inference-build"}
[[ ! -L "$cache" ]] || exit 68
work="$cache/onnxruntime-python-$key"
[[ ! -L "$work" ]] || exit 68
mkdir -p "$work/sysroot"
if [[ ! -f "$work/.prepared" ]]; then
 cp -a --reflink=auto "$sdk_root/sysroot/." "$work/sysroot/"
 cp -a --reflink=auto "$stage/usr/." "$work/sysroot/usr/"
 printf '%s\n' "$key" > "$work/.prepared"
fi
unset CMAKE_TOOLCHAIN_FILE
cmake -S "$repo_root/support/python-onnxruntime-binding" -B "$work/build" -G Ninja \
 -DCMAKE_SYSTEM_NAME=Linux -DCMAKE_SYSTEM_PROCESSOR=riscv64 -DCMAKE_SYSROOT="$work/sysroot" \
 -DCMAKE_FIND_ROOT_PATH="$work/sysroot" -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY -DCMAKE_SKIP_RPATH=ON \
 -DCMAKE_CXX_COMPILER="$sdk_root/bin/riscv64-unknown-linux-gnu-g++" -DCMAKE_CXX_FLAGS=-O1 \
 -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath-link,$work/sysroot/usr/lib" \
 -DORT_SOURCE_ROOT="$source_root" -DORT_BUILD_ROOT="$core/build" \
 -DTARGET_PYTHON_INCLUDE="$work/sysroot/usr/include/python3.13" \
 -DTARGET_NUMPY_INCLUDE="$work/sysroot/usr/lib/python3.13/site-packages/numpy/_core/include"
cmake --build "$work/build" --parallel "${TDVP_JOBS:-4}"
payload=$(tdvp_prepare_generated_payload_root "$package_dir")
site="$payload/usr/lib/python3.13/site-packages"
mkdir -p "$site/onnxruntime" "$site/onnxruntime-1.21.0.dist-info"
cp -a "$work/build/python/onnxruntime/." "$site/onnxruntime/"
# Include the upstream CPU inference utilities/backend and their model data.
for directory in backend datasets; do
 [[ ! -d "$source_root/onnxruntime/python/$directory" ]] || cp -a "$source_root/onnxruntime/python/$directory" "$site/onnxruntime/"
done
mkdir -p "$site/onnxruntime/tools"
for module in "$source_root/onnxruntime/python/tools/"*.py; do
 [[ ! -f "$module" ]] || cp -a "$module" "$site/onnxruntime/tools/"
done
for directory in quantization transformers; do
 [[ ! -d "$source_root/onnxruntime/python/tools/$directory" ]] || cp -a "$source_root/onnxruntime/python/tools/$directory" "$site/onnxruntime/"
done
[[ ! -d "$source_root/onnxruntime/experimental" ]] || cp -a "$source_root/onnxruntime/experimental" "$site/onnxruntime/"
install -m 0644 "$package_dir/files/METADATA" "$site/onnxruntime-1.21.0.dist-info/METADATA"
install -m 0644 "$source_root/LICENSE" "$site/onnxruntime-1.21.0.dist-info/LICENSE"
install -m 0644 "$source_root/ThirdPartyNotices.txt" "$site/onnxruntime-1.21.0.dist-info/ThirdPartyNotices.txt"
tdvp_remove_elf_runtime_search_paths "$sdk_root/bin/riscv64-unknown-linux-gnu-readelf" \
 "$site/onnxruntime/capi/onnxruntime_pybind11_state.so"
python3 "$repo_root/scripts/verify-published-sdk-payload.py" "$sdk_root" "$payload"
python3 "$repo_root/support/install-source-licenses.py" "$source_root" "$package_dir" "$payload" \
  --license-file LICENSE --license-file ThirdPartyNotices.txt
printf '%s\n' "Python ORT source-built payload ready: $payload"
