#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/buildroot-command-package.sh"
# CI builds/audits the ELF only; it never controls a process.
TDVP_COMMAND_FRONTEND_NAMES='cpulimit=tdvp-cpulimit' tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" BR2_PACKAGE_CPULIMIT cpulimit 'CPULIMIT_VERSION = 0.2' 'cpulimit'
