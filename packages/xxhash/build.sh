#!/usr/bin/env bash
# Build the xxHash CLI as a private K230 command, never as a libxxhash ABI.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# xxhsum links its implementation objects directly.  Override Buildroot's
# default library-oriented targets so the private transaction creates neither
# a shared/static libxxhash provider nor development files.  CI audits the
# ELF only; it never invokes xxhsum or supplies a file/payload.
TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES=$'XXHASH_TARGETS=xxhsum\nXXHASH_INSTALL_TARGETS=install_xxhsum' \
TDVP_COMMAND_FRONTEND_NAMES='xxhsum=tdvp-xxhsum' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}" \
    BR2_PACKAGE_XXHASH xxhash 'XXHASH_VERSION = 0.8.3' 'xxhsum'
