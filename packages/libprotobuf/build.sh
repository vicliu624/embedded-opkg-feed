#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/native-cmake-input.sh"
native="${TDVP_FEED_STAGING_ROOT:?}/.tdvp-native/serialization"
tdvp_prepare_native_cmake_input "$package_dir/../libabseil-cpp" "$native/abseil" \
  lib/cmake/absl/abslConfig.cmake -DABSL_ENABLE_INSTALL=ON -DABSL_BUILD_TESTING=OFF \
  -DABSL_PROPAGATE_CXX_STD=ON
tdvp_prepare_native_cmake_input "$package_dir" "$native/protobuf" bin/protoc \
  -DCMAKE_PREFIX_PATH="$native/abseil" -Dprotobuf_ABSL_PROVIDER=package \
  -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF \
  -Dprotobuf_BUILD_LIBPROTOC=ON -Dprotobuf_BUILD_PROTOC_BINARIES=ON \
  -Dprotobuf_WITH_ZLIB=OFF
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'lib*.so*' \
  -DCMAKE_CXX_STANDARD=17 -Dprotobuf_ABSL_PROVIDER=package \
  -Dprotobuf_BUILD_TESTS=OFF -Dprotobuf_BUILD_CONFORMANCE=OFF \
  -Dprotobuf_BUILD_LIBPROTOC=OFF -Dprotobuf_BUILD_PROTOC_BINARIES=OFF \
  -Dprotobuf_BUILD_LIBUPB=ON -DWITH_PROTOC="$native/protobuf/bin/protoc" \
  -Dprotobuf_WITH_ZLIB=ON
