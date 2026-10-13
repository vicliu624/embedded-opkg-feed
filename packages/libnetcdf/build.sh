#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libnetcdf.so.[0-9]*' \
 -DNETCDF_ENABLE_HDF5=ON -DNETCDF_ENABLE_DAP=ON -DNETCDF_ENABLE_NCZARR=ON \
 -DNETCDF_ENABLE_REMOTE_FUNCTIONALITY=ON -DNETCDF_ENABLE_LIBXML2=ON \
 -DNETCDF_ENABLE_TESTS=OFF -DNETCDF_ENABLE_EXAMPLES=OFF -DNETCDF_BUILD_UTILITIES=OFF
