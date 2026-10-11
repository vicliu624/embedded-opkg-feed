#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == --platform && "$2" == tdvp-k230-r1 && "$3" == --sdk-root ]] || exit 64
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/../../support/python-wheel-source.sh"
tdvp_build_python_wheel_source "$package_dir" "$4"
python3 "$package_dir/../../support/install-provider-licenses.py" \
  "${TDVP_FEED_STAGING_ROOT:?}/usr/share/licenses/libflatbuffers" \
  "$package_dir" "$package_dir/root" --provider-package "$package_dir/../libflatbuffers"
mkdir -p "$TDVP_FEED_STAGING_ROOT/usr/share/licenses"
cp -a "$package_dir/root/usr/share/licenses/python3-flatbuffers" "$TDVP_FEED_STAGING_ROOT/usr/share/licenses/"
