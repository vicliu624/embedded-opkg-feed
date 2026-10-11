#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
source "$package_dir/../../support/python-meson-source.sh"
tdvp_build_python_meson_source "$package_dir" "$4" scipy \
  -Dblas=openblas -Dlapack=openblas

# Patch the package projection only; retain the hash-locked upstream source
# and reusable compiled objects. Each projection is freshly recreated.
patch --directory="$package_dir/root/usr/lib/python3.13/site-packages" \
  -p1 --fuzz=0 --forward < "$package_dir/patches/0001-preload-package-local-special-error-state.patch"
