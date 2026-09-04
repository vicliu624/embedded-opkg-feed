#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-node-inputs.sh
source "$package_dir/../../support/buildroot-node-inputs.sh"
tdvp_prepare_node22_icu_inputs "$package_dir" "$4" "${TDVP_NODE22_BUILDROOT_OUTPUT:-}"
tdvp_copy_node22_icu_input_library "$package_dir" 'libicuio.so*'
echo "libicuio payload ready: $package_dir/root"
