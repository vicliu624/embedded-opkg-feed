#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libzmq*.so*' \
  -DBUILD_SHARED=ON -DBUILD_STATIC=OFF -DBUILD_TESTS=OFF \
  -DWITH_DOC=OFF -DWITH_DOCS=OFF -DENABLE_DRAFTS=OFF \
  -DWITH_LIBSODIUM=ON -DWITH_LIBSODIUM_STATIC=OFF -DENABLE_CURVE=ON \
  -DWITH_LIBBSD=OFF
