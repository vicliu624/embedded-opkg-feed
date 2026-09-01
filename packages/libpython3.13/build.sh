#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-python3.sh
source "$package_dir/../../support/buildroot-python3.sh"
tdvp_build_python3_to_stage "$package_dir" "$4" "${TDVP_PYTHON3_BUILDROOT_OUTPUT:-}"
stage_root=${TDVP_FEED_STAGING_ROOT:?Python stage root is required}
[[ -e "$stage_root/usr/lib/libpython3.13.so.1.0" ]] || { echo 'Python staging omitted libpython3.13' >&2; exit 65; }
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/lib"
cp -a "$stage_root/usr/lib/libpython3.13.so"* "$payload_dir/usr/lib/"
echo "libpython3.13 payload ready: $payload_dir"
