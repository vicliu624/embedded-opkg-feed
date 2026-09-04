#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
TDVP_COMMAND_FRONTEND_NAMES='grep=tdvp-grep' \
tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_GREP grep 'GREP_VERSION = 3.11' 'grep'
