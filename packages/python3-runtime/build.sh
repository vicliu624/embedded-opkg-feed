#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -d "$stage_root/usr/lib/python3.13" && -e "$stage_root/usr/lib/libpython3.13.so.1.0" ]] || {
  echo 'python3-runtime requires libpython3.13 to populate the release staging root first' >&2; exit 65;
}
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/lib"
cp -a "$stage_root/usr/lib/python3.13" "$payload_dir/usr/lib/python3.13"
echo "python3-runtime payload ready: $payload_dir"
