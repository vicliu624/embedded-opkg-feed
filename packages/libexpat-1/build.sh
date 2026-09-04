#!/usr/bin/env bash
# Build the public Expat SONAME once; leaf applications receive it through the
# runtime-owner map instead of bundling an XML parser.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "libexpat-1 does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_LIBEXPAT_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-archive-library.sh
source "$package_dir/../../support/buildroot-archive-library.sh"

tdvp_build_archive_library "$package_dir" "$sdk_root" "$configured_output" \
  BR2_PACKAGE_EXPAT expat 'libexpat.so*' 'EXPAT_VERSION = 2.7.0'
