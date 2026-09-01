#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/python3" ]] || { echo 'python3 requires python3-runtime staging first' >&2; exit 65; }
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin"
cp -a "$stage_root/usr/bin/python" "$stage_root/usr/bin/python3" "$payload_dir/usr/bin/"
echo "python3 payload ready: $payload_dir"
