#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/buildroot-command-package.sh"

# Retain only the private command. librhash.a is a build-time implementation;
# no librhash shared provider or header is copied into the feed payload. CI
# builds and audits the ELF only and never gives rhash a file path or payload.
TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_RHASH_BIN' \
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES=$'RHASH_CONF_OPTS=--disable-gettext --disable-openssl\nRHASH_BUILD_TARGETS=lib-static build\nRHASH_INSTALL_TARGETS=install-lib-static' \
TDVP_COMMAND_FRONTEND_NAMES='rhash=tdvp-rhash' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_RHASH rhash 'RHASH_VERSION = 1.4.4' 'rhash'
