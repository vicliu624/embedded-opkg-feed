#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export PYYAML_FORCE_CYTHON=1
source "$package_dir/../../support/python-wheel-source.sh"
tdvp_build_python_wheel_source "$package_dir" "$4"
