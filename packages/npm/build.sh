#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/npm" && -x "$stage_root/usr/bin/npx" ]] || {
  echo 'npm requires npm-runtime to populate npm/npx frontends first' >&2; exit 65;
}
payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin"
for command in npm npx corepack; do
  [[ -e "$stage_root/usr/bin/$command" ]] || continue
  cp -a -- "$stage_root/usr/bin/$command" "$payload_dir/usr/bin/$command"
done
echo "npm payload ready: $payload_dir"
