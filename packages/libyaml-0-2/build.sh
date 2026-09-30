#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/buildroot-archive-library.sh"
tdvp_build_archive_library "$package_dir" "$4" "${TDVP_ARCHIVE_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_LIBYAML libyaml 'libyaml*.so*' 'LIBYAML_VERSION = 0.2.5'
