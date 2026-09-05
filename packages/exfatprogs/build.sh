#!/usr/bin/env bash
# Build the locked exfatprogs suite and expose only explicit TDVP frontends.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# Buildroot installs these maintenance commands in its temporary sbin tree.
# The shared helper copies only this reviewed list into the private libexec
# namespace, then emits collision-free tdvp-exfat-* frontends in /usr/bin.
TDVP_COMMAND_FRONTEND_NAMES='mkfs.exfat=tdvp-exfat-mkfs fsck.exfat=tdvp-exfat-fsck dump.exfat=tdvp-exfat-dump exfat2img=tdvp-exfat-image tune.exfat=tdvp-exfat-tune exfatlabel=tdvp-exfat-label' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_EXFATPROGS_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_EXFATPROGS exfatprogs 'EXFATPROGS_VERSION = 1.2.5' \
  'mkfs.exfat fsck.exfat dump.exfat exfat2img tune.exfat exfatlabel'
