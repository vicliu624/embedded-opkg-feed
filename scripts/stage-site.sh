#!/usr/bin/env bash
# Stage a signed immutable feed for Pages without replacing a prior release.
set -Eeuo pipefail

if [[ $# -ne 3 || "$1" != '--platform' ]]; then
  echo "usage: $0 --platform <platform-slug> <signed-feed-directory>" >&2
  exit 64
fi

platform_slug=$2
source_feed=$(cd -- "$3" && pwd)
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
platform_file="$repo_root/platforms/$platform_slug/platform.env"
[[ -f "$platform_file" ]] || { echo "unknown platform: $platform_slug" >&2; exit 65; }
# shellcheck source=/dev/null
source "$platform_file"

"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$source_feed"
target_dir="$repo_root/site/feed/$PLATFORM_ID/$ARCH"
if [[ -e "$target_dir/Packages" || -e "$target_dir/Packages.gz" ]]; then
  echo "refusing to replace staged immutable feed: $target_dir" >&2; exit 66;
fi
mkdir -p -- "$target_dir"
cp -a -- "$source_feed/." "$target_dir/"
cat >"$target_dir/release.json" <<EOF
{
  "platform_slug": "$PLATFORM_SLUG",
  "platform_id": "$PLATFORM_ID",
  "architecture": "$ARCH",
  "index": "Packages.gz",
  "signature": "Packages.gz.asc"
}
EOF
echo "staged public feed: $target_dir"
