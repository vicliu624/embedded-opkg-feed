#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/python-wheel-source.sh"
# Upstream tags require explicit target overrides even without a bundled DSO.
export PYSOUNDFILE_PLATFORM=linux
export PYSOUNDFILE_ARCHITECTURE=riscv64
tdvp_build_python_wheel_source "$package_dir" "$4"
