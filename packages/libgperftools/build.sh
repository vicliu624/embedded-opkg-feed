#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/source-archive-library.sh"
[[ -f "${TDVP_FEED_STAGING_ROOT:?}/usr/include/libunwind.h" ]] || {
  echo 'gperftools requires the libunwind development provider' >&2
  exit 66
}
tdvp_build_direct_archive_library "$package_dir" "$4" '' 'gperftools-2.18.1' 'lib*.so.[0-9]*' -- --enable-libunwind
