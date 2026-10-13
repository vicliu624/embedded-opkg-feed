#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libpaho-mqtt*.so*' \
  -DPAHO_BUILD_SHARED=ON -DPAHO_BUILD_STATIC=OFF -DPAHO_WITH_SSL=ON \
  -DPAHO_ENABLE_TESTING=OFF -DPAHO_ENABLE_CPACK=OFF -DPAHO_BUILD_SAMPLES=OFF \
  -DPAHO_HIGH_PERFORMANCE=ON
