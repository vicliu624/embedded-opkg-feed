#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}
package_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# The immutable target-runtime catalogue explicitly owns libcap.so.2 as
# libcap-2 (= 2025.02.1-1). htop may retain capability view only through that
# exact dependency; it neither rebuilds nor embeds a separate libcap ABI.
tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_HTOP htop 'HTOP_VERSION = 3.3.0' 'htop'
