#!/usr/bin/env bash
# Build the locked netcat source into a package-private nc command. The
# temporary Buildroot configuration exposes the non-BusyBox command, while
# base-overlay verification prevents publication if firmware owns that path.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_NETCAT netcat 'NETCAT_VERSION = 0.7.1' 'nc'
