#!/usr/bin/env bash
# Build the public libffi ABI before source-building clients such as CPython
# _ctypes. It is a reusable provider, never a private library copy in Python.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "libffi-8 does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_LIBFFI_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-archive-library.sh
source "$package_dir/../../support/buildroot-archive-library.sh"

tdvp_build_archive_library "$package_dir" "$sdk_root" "$configured_output" \
  BR2_PACKAGE_LIBFFI libffi 'libffi.so*' 'LIBFFI_VERSION = 3.4.6'
