#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libaom.so.[0-9]*' \
  -DBUILD_SHARED_LIBS=ON -DAOM_TARGET_CPU=generic -DCONFIG_RUNTIME_CPU_DETECT=0 \
  -DENABLE_TESTS=OFF -DENABLE_DOCS=OFF -DENABLE_EXAMPLES=OFF -DENABLE_TOOLS=OFF
