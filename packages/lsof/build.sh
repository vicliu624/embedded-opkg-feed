#!/usr/bin/env bash
# Build lsof from the locked Buildroot source into an IPK-private command.
# K230's immutable BusyBox already owns /usr/bin/lsof, so the full program is
# deliberately exposed as /usr/bin/tdvp-lsof instead of replacing that applet.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
configured_output=$(printenv TDVP_DEVEL_BUILDROOT_OUTPUT || true)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
grep -Fqx 'BR2_USE_MMU=y' "$output/.config" || {
  echo 'matching Buildroot output lacks required lsof toolchain feature: BR2_USE_MMU=y' >&2
  exit 65
}

# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# Buildroot only links libtirpc when the baseline happens to select it. lsof's
# Linux /proc inspection works without RPC support, so keep that optional
# runtime outside this leaf candidate until it has an independent provider.
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_LIBTIRPC' \
TDVP_COMMAND_FRONTEND_NAMES='lsof=tdvp-lsof' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "$configured_output" \
    BR2_PACKAGE_LSOF lsof 'LSOF_VERSION = 4.99.4' 'lsof'
