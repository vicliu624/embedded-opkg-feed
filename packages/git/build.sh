#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64;
}
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/git" && -d "$stage_root/usr/libexec/git-core" ]] || {
  echo 'git requires git-runtime to populate the release staging root first' >&2; exit 65;
}
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin"
cp -a "$stage_root/usr/bin/git" "$payload_dir/usr/bin/git"
echo "git payload ready: $payload_dir"
