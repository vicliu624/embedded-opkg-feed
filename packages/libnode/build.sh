#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || { echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2; exit 64; }
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/node22-source-build.sh
source "$package_dir/../../support/node22-source-build.sh"
# shellcheck source=../../support/source-archive-library.sh
source "$package_dir/../../support/source-archive-library.sh"
tdvp_build_node22_to_stage "$package_dir" "$4" "${TDVP_NODE22_BUILDROOT_OUTPUT:-}"
stage_root=${TDVP_FEED_STAGING_ROOT:?Node stage root is required}
[[ -e "$stage_root/usr/lib/libnode.so.127" ]] || { echo 'Node stage omitted libnode.so.127' >&2; exit 65; }
payload_dir=$(tdvp_prepare_generated_payload_root "$package_dir")
mkdir -p -- "$payload_dir/usr/lib"
cp -a -- "$stage_root/usr/lib/libnode.so"* "$payload_dir/usr/lib/"
python3 "$package_dir/../../support/install-archive-source-license.py" \
  "$(tdvp_source_archive_locked_file "$package_dir")" "$package_dir" "$payload_dir" 'node-v22.23.2/LICENSE'
echo "libnode payload ready: $payload_dir"
