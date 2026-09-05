#!/usr/bin/env bash
# Build a target-only gdbserver from locked GNU GDB source. The full debugger,
# TUI, Python integration, and SDK debug-root installation hook are excluded.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}")
for required_config in BR2_USE_MMU=y BR2_TOOLCHAIN_HAS_THREADS=y BR2_TOOLCHAIN_HAS_THREADS_DEBUG=y BR2_INSTALL_LIBSTDCPP=y BR2_TOOLCHAIN_GCC_AT_LEAST_9=y; do
  grep -Fqx "$required_config" "$output/.config" || {
    echo "matching Buildroot output lacks required gdbserver feature: $required_config" >&2
    exit 65
  }
done

# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"
# GDB's gdbserver-only recipe still has an SDK-install hook that would place a
# copy under output/host/.../debug-root. Clear that hook for this transaction:
# the candidate owns only its extracted private target ELF. No target GDB,
# TUI, Python, zlib/ncurses, GMP, or MPFR feature is enabled.
TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_GDB_SERVER' \
TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_GDB_DEBUGGER BR2_PACKAGE_GDB_TUI BR2_PACKAGE_GDB_PYTHON' \
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='GDB_VERSION=15.1
GDB_POST_INSTALL_TARGET_HOOKS=' \
TDVP_COMMAND_FRONTEND_NAMES='gdbserver=tdvp-gdbserver' \
  tdvp_buildroot_command_package "$package_dir" "$sdk_root" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_GDB gdb 'GDB_SOURCE = gdb-$(GDB_VERSION).tar.xz' 'gdbserver'
