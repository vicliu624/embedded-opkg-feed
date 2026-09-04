#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -d "$stage_root/usr/lib/node_modules/npm" ]] || {
  echo 'npm-runtime requires the Node source build to populate npm data first' >&2; exit 65;
}
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p -- "$payload_dir/usr/lib/node_modules"
cp -a -- "$stage_root/usr/lib/node_modules/npm" "$payload_dir/usr/lib/node_modules/npm"
if [[ -d "$stage_root/usr/lib/node_modules/corepack" ]]; then
  cp -a -- "$stage_root/usr/lib/node_modules/corepack" "$payload_dir/usr/lib/node_modules/corepack"
fi
echo "npm-runtime payload ready: $payload_dir"
