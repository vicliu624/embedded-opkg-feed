#!/usr/bin/env bash
# Build private inotify CLI tools from the locked GitHub source release.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# The upstream project normally exposes libinotifytools as a shared library.
# Disable shared output and request a static command-side link; the helper then
# copies only the two reviewed CLI ELF files into the private TDVP namespace.
# CI never starts a watcher or supplies a path for these commands to observe.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='INOTIFY_TOOLS_CONF_OPTS=--disable-shared --enable-static --enable-static-binary --disable-doxygen' \
TDVP_COMMAND_FRONTEND_NAMES='inotifywait=tdvp-inotify-wait inotifywatch=tdvp-inotify-watch' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_INOTIFY_TOOLS_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_INOTIFY_TOOLS inotify-tools 'INOTIFY_TOOLS_VERSION = 3.20.2.2' \
    'inotifywait inotifywatch'
