#!/usr/bin/env bash
# Stage a signed immutable feed for Pages without replacing a prior release.
set -Eeuo pipefail

platform_slug=
source_feed=
release=r1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --release)
      [[ $# -ge 2 ]] || { echo '--release needs a value' >&2; exit 64; }
      release=$2
      shift 2
      ;;
    *)
      [[ -z "$source_feed" ]] || { echo "unexpected argument: $1" >&2; exit 64; }
      source_feed=$1
      shift
      ;;
  esac
done
[[ -n "$platform_slug" && -n "$source_feed" ]] || {
  echo "usage: $0 --platform <platform-slug> [--release <rN>] <signed-feed-directory>" >&2
  exit 64
}
source_feed=$(cd -- "$source_feed" && pwd)
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$source_feed"
release_path=$(tdvp_feed_release_path "$release")
target_dir="$repo_root/site/feed/$release_path"
if [[ -e "$target_dir/Packages" || -e "$target_dir/Packages.gz" ]]; then
  echo "refusing to replace staged immutable feed: $target_dir" >&2; exit 66;
fi
mkdir -p -- "$target_dir"
cp -a -- "$source_feed/." "$target_dir/"
cat >"$target_dir/release.json" <<EOF
{
  "platform_slug": "$PLATFORM_SLUG",
  "platform_id": "$PLATFORM_ID",
  "feed_release": "$release",
  "architecture": "$ARCH",
  "index": "Packages.gz",
  "signature": "Packages.asc"
}
EOF
# A Windows checkout does not reliably preserve an executable bit for a newly
# added shell script. Invoke the renderer through Bash just as build-all.sh
# invokes package recipes, so staging remains portable between Windows and WSL.
bash "$script_dir/render-site-index.sh"
echo "staged public feed: $target_dir"
