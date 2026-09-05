#!/usr/bin/env bash
# Build a private logrotate command from the locked GitHub source release.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# The private command may use the immutable target libpopt runtime, but it
# must not add SELinux/ACL providers or package Buildroot's /etc configuration.
# CI only builds and audits the ELF; it never invokes logrotate on any path.
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_LIBSELINUX BR2_PACKAGE_ACL' \
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='LOGROTATE_CONF_OPTS=--without-selinux --without-acl' \
TDVP_COMMAND_FRONTEND_NAMES='logrotate=tdvp-logrotate' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_LOGROTATE_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_LOGROTATE logrotate 'LOGROTATE_VERSION = 3.22.0' 'logrotate'
