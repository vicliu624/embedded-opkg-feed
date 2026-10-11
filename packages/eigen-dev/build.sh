#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" '@development' \
  -DBUILD_TESTING=OFF -DEIGEN_BUILD_TESTING=OFF \
  -DEIGEN_BUILD_BLAS=OFF -DEIGEN_BUILD_LAPACK=OFF \
  -DEIGEN_BUILD_DEMOS=OFF -DEIGEN_BUILD_BTL=OFF -DEIGEN_BUILD_SPBENCH=OFF \
  -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_PKGCONFIG=ON -DEIGEN_BUILD_CMAKE_PACKAGE=ON
