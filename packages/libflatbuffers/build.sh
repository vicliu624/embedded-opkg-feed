#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libflatbuffers.so*' \
  -DFLATBUFFERS_BUILD_TESTS=OFF -DFLATBUFFERS_BUILD_FLATC=OFF \
  -DFLATBUFFERS_BUILD_FLATHASH=OFF -DFLATBUFFERS_BUILD_GRPCTEST=OFF \
  -DFLATBUFFERS_BUILD_FLATLIB=OFF -DFLATBUFFERS_BUILD_SHAREDLIB=ON
