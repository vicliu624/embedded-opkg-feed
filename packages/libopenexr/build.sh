#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/cmake-source-library.sh"
# Require feed development inputs before configuration can select bundled copies.
for header in Imath/half.h openjph/ojph_codestream.h libdeflate.h zstd.h; do
  [[ -f "$TDVP_FEED_STAGING_ROOT/usr/include/$header" ]] || { echo "Missing OpenEXR development provider: $header" >&2; exit 66; }
done
tdvp_build_cmake_source_library "$package_dir" "$4" '*-3_5.so.[0-9]*' \
  -DBUILD_SHARED_LIBS=ON -DBUILD_TESTING=OFF -DBUILD_WEBSITE=OFF \
  -DOPENEXR_BUILD_TOOLS=OFF -DOPENEXR_INSTALL_TOOLS=OFF -DOPENEXR_BUILD_EXAMPLES=OFF \
  -DOPENEXR_BUILD_PYTHON=OFF -DOPENEXR_INSTALL_DOCS=OFF -DFETCHCONTENT_FULLY_DISCONNECTED=ON
