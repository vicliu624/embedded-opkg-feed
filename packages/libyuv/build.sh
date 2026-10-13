#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$4/environment-setup.sh"
source "$package_dir/../../support/cmake-source-library.sh"
# Upstream's runtime SONAME is libyuv.so; it is intentionally unversioned.
tdvp_build_cmake_source_library "$package_dir" "$4" 'libyuv.so' -DUNIT_TEST=OFF \
  -DCMAKE_C_FLAGS="$CFLAGS -fPIC -O1 -DLIBYUV_DISABLE_RVV" \
  -DCMAKE_CXX_FLAGS="$CXXFLAGS -fPIC -O1 -DLIBYUV_DISABLE_RVV"
