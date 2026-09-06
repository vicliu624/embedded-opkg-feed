#!/usr/bin/env bash
# Build pigz as one private K230 command, never as a replacement for BusyBox.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# pigz is a command-only package. Buildroot supplies its zlib build dependency
# from the matching SDK; the helper extracts only the RISC-V pigz ELF, places
# it beneath a private libexec directory, and creates tdvp-pigz. CI never
# invokes the command or supplies data for compression/decompression.
TDVP_COMMAND_FRONTEND_NAMES='pigz=tdvp-pigz' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_PIGZ pigz 'PIGZ_VERSION = 2.8' 'pigz'
