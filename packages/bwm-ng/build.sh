#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/buildroot-command-package.sh"
# Use the SDK's immutable ncurses runtime when its reviewed configuration enables
# the optional terminal view.  This transaction builds no runtime provider and CI
# never invokes the monitor or observes procfs, network, or disk-I/O data.
TDVP_COMMAND_FRONTEND_NAMES='bwm-ng=tdvp-bwm-ng' tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" BR2_PACKAGE_BWM_NG bwm-ng 'BWM_NG_VERSION = 0.6.3' 'bwm-ng'
