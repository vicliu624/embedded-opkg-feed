#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-archive-library.sh
source "$package_dir/../../support/buildroot-archive-library.sh"
tdvp_build_archive_library "$package_dir" "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_FILE file 'libmagic.so*' 'FILE_VERSION = 5.45'
