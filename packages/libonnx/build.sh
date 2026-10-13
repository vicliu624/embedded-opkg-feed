#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$package_dir/../.." && pwd)
source "$package_dir/package.env"
source "$repo_root/support/native-cmake-input.sh"
native_root=${TDVP_NATIVE_PROTOBUF_ROOT:-"${TDVP_FEED_STAGING_ROOT:?}/.tdvp-native/serialization"}
protobuf_package=$(cd -- "$package_dir/../libprotobuf" && pwd)
tdvp_prepare_native_cmake_input "$package_dir/../libabseil-cpp" "$native_root/abseil" \
  lib/cmake/absl/abslConfig.cmake -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF \
  -DABSL_PROPAGATE_CXX_STD=ON
tdvp_prepare_native_cmake_input "$protobuf_package" "$native_root/protobuf" bin/protoc \
  -DCMAKE_PREFIX_PATH="$native_root/abseil" -Dprotobuf_ABSL_PROVIDER=package \
  -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF \
  -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_BUILD_PROTOC_BINARIES=ON -Dprotobuf_WITH_ZLIB=OFF
[[ "$("$native_root/protobuf/bin/protoc" --version)" == 'libprotoc 29.3' ]] || exit 65
source "$repo_root/support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libonnx*.so*' \
  -DCMAKE_CXX_STANDARD=17 -DCMAKE_CXX_FLAGS_RELEASE=-DNDEBUG \
  -DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON \
  -DCMAKE_PROJECT_INCLUDE="$repo_root/support/onnx-import-protobuf.cmake" \
  -DONNX_CUSTOM_PROTOC_EXECUTABLE="$native_root/protobuf/bin/protoc" \
  -DPYTHON_EXECUTABLE=/usr/bin/python3 -DONNX_GEN_PB_TYPE_STUBS=OFF \
  -DONNX_USE_PROTOBUF_SHARED_LIBS=ON -DONNX_USE_LITE_PROTO=OFF -DONNX_ML=ON \
  -DBUILD_ONNX_PYTHON=OFF -DONNX_BUILD_TESTS=OFF -DONNX_WERROR=OFF \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
