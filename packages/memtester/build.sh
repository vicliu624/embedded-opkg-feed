#!/usr/bin/env bash
# Build the locked memtester command and expose only an explicit TDVP frontend.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-command-package.sh
source "$package_dir/../../support/buildroot-command-package.sh"

# This command can consume and write large regions of user-selected memory.
# The helper only cross-compiles and packages it; neither CI nor local policy
# checks executes the resulting target program.
TDVP_COMMAND_FRONTEND_NAMES='memtester=tdvp-memtester' \
  tdvp_buildroot_command_package "$package_dir" "$4" "${TDVP_MEMTESTER_BUILDROOT_OUTPUT:-}" \
  BR2_PACKAGE_MEMTESTER memtester 'MEMTESTER_VERSION = 4.5.1' 'memtester'
