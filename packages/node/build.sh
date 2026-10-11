#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/node" && -e "$stage_root/usr/lib/libnode.so.127" ]] || {
  echo 'node requires libnode to populate the release staging root first' >&2; exit 65;
}
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p -- "$payload_dir/usr/bin"
cp -a -- "$stage_root/usr/bin/node" "$payload_dir/usr/bin/node"
python3 "$package_dir/../../support/install-archive-source-license.py" \
  "$(tdvp_source_archive_locked_file "$package_dir")" "$package_dir" "$payload_dir" 'node-v22.23.2/LICENSE'
echo "node payload ready: $payload_dir"
