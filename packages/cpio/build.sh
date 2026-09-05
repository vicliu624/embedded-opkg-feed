#!/usr/bin/env bash
# Build a private GNU cpio command from the locked GNU release.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# CI builds and audits the ELF only. It never invokes cpio, supplies an
# archive, or reads from or writes to a filesystem path through cpio.
TDVP_COMMAND_FRONTEND_NAMES='cpio=tdvp-cpio' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_ARCHIVE_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_CPIO cpio 'CPIO_VERSION = 2.15' 'cpio'
