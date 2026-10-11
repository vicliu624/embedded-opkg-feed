#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libncnn.so*' \
  -DNCNN_VERSION=20250503 -DNCNN_SHARED_LIB=ON -DNCNN_INSTALL_SDK=ON \
  -DNCNN_BUILD_TOOLS=OFF -DNCNN_BUILD_EXAMPLES=OFF -DNCNN_BUILD_TESTS=OFF \
  -DNCNN_BUILD_BENCHMARK=OFF -DNCNN_VULKAN=OFF -DNCNN_OPENMP=OFF \
  -DNCNN_RUNTIME_CPU=OFF -DNCNN_RVV=OFF -DNCNN_XTHEADVECTOR=OFF \
  -DNCNN_ZFH=OFF -DNCNN_ZVFH=OFF \
  -DNCNN_C_API=ON -DNCNN_PYTHON=OFF
