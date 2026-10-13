#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
# ENABLE_DECODER controls the dec265 sample executable, not the decoder library.
tdvp_build_cmake_source_library "$package_dir" "$4" 'libde265.so.[0-9]*' \
  -DBUILD_SHARED_LIBS=ON -DENABLE_SIMD=OFF -DENABLE_AVX2=OFF -DENABLE_AVX512=OFF \
  -DENABLE_SDL=OFF -DENABLE_DECODER=OFF -DENABLE_ENCODER=OFF \
  -DENABLE_SHERLOCK265=OFF -DENABLE_INTERNAL_DEVELOPMENT_TOOLS=OFF -DWITH_FUZZERS=OFF
