#!/usr/bin/env bash
# Build a private JSON construction command from the locked GitHub release.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# Buildroot suppresses pandoc/manpage generation. CI only builds and audits
# the ELF; it never executes jo or gives it JSON input to process.
TDVP_COMMAND_FRONTEND_NAMES='jo=tdvp-jo' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_JO_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_JO jo 'JO_VERSION = 1.6' 'jo'
