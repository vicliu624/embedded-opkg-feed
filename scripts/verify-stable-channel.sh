#!/usr/bin/env bash
# Prove that the mutable stable endpoint is a complete, byte-identical view of
# one signed immutable rN snapshot.  release.json is descriptive metadata;
# opkg's actual trust decision remains the detached Packages signatures.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 2 || "$1" != '--platform' ]]; then
  echo "usage: $0 --platform <platform-slug>" >&2
  exit 64
fi

platform_slug=$2
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

site_dir=${TDVP_FEED_SITE_ROOT:-"$repo_root/site"}
site_dir=$(cd -- "$site_dir" && pwd)

channel_path=$(tdvp_feed_channel_path stable)
channel_dir="$site_dir/feed/$channel_path"
metadata="$channel_dir/release.json"
[[ -s "$metadata" ]] || { echo "missing stable channel metadata: $metadata" >&2; exit 65; }

require_metadata_line() {
  local key=$1
  local value=$2
  grep -Fqx "  \"$key\": \"$value\"," "$metadata" || {
    echo "stable metadata mismatch: $key" >&2
    exit 66
  }
}

require_metadata_line publication_type mutable-channel
require_metadata_line channel stable
require_metadata_line platform_slug "$PLATFORM_SLUG"
require_metadata_line platform_id "$PLATFORM_ID"
require_metadata_line architecture "$ARCH"

release=$(sed -n 's/^  "feed_release": "\(r[1-9][0-9]*\)",$/\1/p' "$metadata")
[[ -n "$release" && "$(printf '%s\n' "$release" | wc -l | tr -d ' ')" == 1 ]] || {
  echo "stable metadata has no valid immutable feed_release" >&2
  exit 67
}
release_path=$(tdvp_feed_release_path "$release")
require_metadata_line source_release_path "$release_path"
source_dir="$site_dir/feed/$release_path"
[[ -d "$source_dir" ]] || { echo "stable source release is missing: $source_dir" >&2; exit 68; }

"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$source_dir"
"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$channel_dir"

for name in Packages Packages.gz Packages.asc Packages.gz.asc; do
  cmp -- "$source_dir/$name" "$channel_dir/$name" || {
    echo "stable channel does not preserve $name from $release" >&2
    exit 69
  }
done

while IFS= read -r package_file; do
  cmp -- "$source_dir/$package_file" "$channel_dir/$package_file" || {
    echo "stable channel does not preserve package payload: $package_file" >&2
    exit 70
  }
done < <(awk '/^Filename: / { print $2 }' "$source_dir/Packages")

echo "stable channel verification passed: $channel_dir <= $source_dir"
