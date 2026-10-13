#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libdate-tz.so*' \
  -DBUILD_TZ_LIB=ON -DUSE_SYSTEM_TZ_DB=ON -DENABLE_DATE_TESTING=OFF \
  -DENABLE_DATE_INSTALL=ON -DCMAKE_CXX_STANDARD=17
