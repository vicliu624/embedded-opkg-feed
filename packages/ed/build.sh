#!/usr/bin/env bash
# Build a private GNU ed command from the locked GNU release.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# CI builds and audits the ELF but never starts an editor or supplies a file.
TDVP_COMMAND_FRONTEND_NAMES='ed=tdvp-ed' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_ED_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_ED ed 'ED_VERSION = 1.20.2' 'ed'
