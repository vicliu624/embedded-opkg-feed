#!/usr/bin/env bash
# Build the current psmisc release as private process-inspection commands.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# Buildroot 2025.02.1 contributes only the reviewed cross-build recipe, not
# the old 23.5 source. PSMISC_VERSION is passed as one guarded make argument;
# the helper supplies the exact 23.7 archive from this recipe's offline source
# cache. Five ordinary process commands remain under a private libexec tree.
# CI compiles/audits ELF metadata only. It never runs an included command,
# reads procfs, supplies a PID/name/path/socket, or signals a process.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='PSMISC_VERSION=23.7' \
TDVP_COMMAND_FRONTEND_NAMES='fuser=tdvp-fuser killall=tdvp-killall pslog=tdvp-pslog prtstat=tdvp-prtstat pstree=tdvp-pstree' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_PSMISC psmisc 'PSMISC_VERSION = 23.5' \
    'fuser killall pslog prtstat pstree'
