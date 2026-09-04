#!/usr/bin/env bash
# Build CPython only from its locked release archive; this package owns the
# public shared ABI and initialises the private three-way source-build stage.
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# shellcheck source=../../support/python3-source-build.sh
source "$package_dir/../../support/python3-source-build.sh"
tdvp_build_python3_source_stage "$package_dir" "$4" "${TDVP_PYTHON3_BUILDROOT_OUTPUT:-}"
tdvp_prepare_python_payload "$package_dir" libpython "$4"
