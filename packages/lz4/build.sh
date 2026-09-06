#!/usr/bin/env bash
# Build the reviewed LZ4 command suite privately, never as a firmware ABI.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# Buildroot normally follows the firmware's shared-library policy. This leaf
# forces the LZ4 build itself to omit liblz4.so, while the generic helper still
# extracts only the four reviewed command paths into a private libexec tree.
# CI builds/audits ELF metadata only; it never gives this codec content or runs
# compression/decompression.
TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_LZ4_PROGS' \
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='LZ4_MAKE_OPTS=BUILD_SHARED=no' \
TDVP_COMMAND_FRONTEND_NAMES='lz4=tdvp-lz4 lz4c=tdvp-lz4c unlz4=tdvp-unlz4 lz4cat=tdvp-lz4cat' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_LZ4 lz4 'LZ4_VERSION = 1.10.0' 'lz4 lz4c unlz4 lz4cat'
