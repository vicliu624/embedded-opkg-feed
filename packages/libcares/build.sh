#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
tdvp_build_direct_archive_library "$package_dir" "$4" "${TDVP_LIBCARES_BUILDROOT_OUTPUT:-}" \
  'c-ares-1.34.2' 'libcares.so*' -- --with-random=/dev/urandom
