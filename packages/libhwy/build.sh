#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libhwy*.so.[0-9]*' \
  "-DCMAKE_PROJECT_INCLUDE=$package_dir/cpu0-scalar.cmake" \
  -DHWY_CMAKE_RVV=OFF \
  -DHWY_ENABLE_CONTRIB=ON -DHWY_ENABLE_EXAMPLES=OFF -DHWY_ENABLE_TESTS=OFF \
  -DBUILD_TESTING=OFF -DFETCHCONTENT_FULLY_DISCONNECTED=ON
