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
# The matching SDK enables libcap globally, but importing its runtime merely
# for htop's optional capability view would violate the feed's explicit-owner
# rule. Core process viewing remains available without this optional feature.
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_LIBCAP' \
tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_HTOP htop 'HTOP_VERSION = 3.3.0' 'htop'
