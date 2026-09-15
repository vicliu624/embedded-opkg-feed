#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}")
for required_config in BR2_USE_MMU=y BR2_PACKAGE_NCURSES=y; do grep -Fqx "$required_config" "$output/.config" || { echo "matching Buildroot output lacks required ncdu feature: $required_config" >&2; exit 65; }; done
source "$package_dir/../../support/buildroot-command-package.sh"
tdvp_buildroot_command_package "$package_dir" "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" BR2_PACKAGE_NCDU ncdu 'NCDU_VERSION = 1.21' 'ncdu'
