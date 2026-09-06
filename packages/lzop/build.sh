#!/usr/bin/env bash
# Build LZOP as one private K230 command, with LZO linked statically only.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# The firmware normally permits shared libraries. This leaf instead builds
# LZO static-only inside the private Buildroot transaction, then extracts only
# lzop below a private libexec path. CI builds/audits ELF metadata only; it
# never supplies content to or runs this compressor/decompressor.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES='LZO_CONF_OPTS=-DENABLE_SHARED=OFF -DENABLE_STATIC=ON' \
TDVP_COMMAND_FRONTEND_NAMES='lzop=tdvp-lzop' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_SYSTEM_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_LZOP lzop 'LZOP_VERSION = 1.04' 'lzop'
