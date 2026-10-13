#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../scripts/feed-platform.sh"
tdvp_assert_package_host_dependencies "$package_dir"
source "$package_dir/../../support/source-archive-library.sh"
tdvp_build_direct_archive_library "$package_dir" "$4" "${TDVP_ARCHIVE_BUILDROOT_OUTPUT:-}" \
  'tiff-4.7.0' 'libtiff*.so*' -- --disable-tools --disable-tests --disable-contrib \
  --disable-webp --disable-jbig --disable-lerc --disable-libdeflate --enable-cxx
