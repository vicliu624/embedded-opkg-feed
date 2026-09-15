#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}")
for required_config in BR2_USE_MMU=y BR2_USE_WCHAR=y BR2_ENABLE_LOCALE=y BR2_PACKAGE_NCURSES=y; do
  grep -Fqx "$required_config" "$output/.config" || { echo "matching Buildroot output lacks required tmux feature: $required_config" >&2; exit 65; }
done
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# Systemd and utf8proc are desktop-wide Kconfig selections.  Keep that
# baseline intact and disable only tmux's optional configure branches, so the
# resulting command retains its reviewed libevent/ncurses-only runtime graph.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='TMUX_CONF_OPTS=--disable-systemd --disable-utf8proc' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_TMUX tmux 'TMUX_VERSION = 3.3a' 'tmux'
