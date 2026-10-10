#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
tdvp_build_cmake_source_library "$package_dir" "$4" 'libavif.so.[0-9]*' \
  -DAVIF_CODEC_AOM=SYSTEM -DAVIF_LIBYUV=SYSTEM -DAVIF_CODEC_AOM_ENCODE=ON \
  -DAVIF_CODEC_AOM_DECODE=ON -DAVIF_BUILD_APPS=OFF -DAVIF_BUILD_TESTS=OFF \
  -DFETCHCONTENT_FULLY_DISCONNECTED=ON
