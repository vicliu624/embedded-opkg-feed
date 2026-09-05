#!/usr/bin/env bash
# Publish libcap's public ABI before htop enables its optional capability view.
# The library is a reusable provider, never a private htop payload.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || {
  echo "libcap-2 does not support platform: $2" >&2
  exit 65
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_LIBCAP_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-archive-library.sh
source "$package_dir/../../support/buildroot-archive-library.sh"

# The optional capsh/setcap/getcap tool suite is neither a runtime ABI nor a
# htop prerequisite. Extract only libcap.so.2* from the locked source build.
tdvp_build_archive_library "$package_dir" "$sdk_root" "$configured_output" \
  BR2_PACKAGE_LIBCAP libcap 'libcap.so.2*' 'LIBCAP_VERSION = 2.73' \
  --disable BR2_PACKAGE_LIBCAP_TOOLS
