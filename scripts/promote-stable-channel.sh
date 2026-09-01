#!/usr/bin/env bash
# Promote one already signed immutable rN snapshot to the ABI-fixed `stable`
# opkg endpoint.  The channel is intentionally mutable; its payload is not.
# A complete, byte-identical copy makes the operation portable to GitHub Pages
# and preserves opkg's basename-only Filename convention.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
release=
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
      echo "unexpected argument: $1" >&2
      exit 64
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$release" ]] || {
  echo "usage: $0 --platform <platform-slug> --release <rN>" >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

# Release operators normally use the repository's site/ tree.  Allow an
# isolated tree for verification, so a candidate promotion never has to touch
# a developer's staged public content.
site_dir=${TDVP_FEED_SITE_ROOT:-"$repo_root/site"}
site_dir=$(cd -- "$site_dir" && pwd)

release_path=$(tdvp_feed_release_path "$release")
channel_path=$(tdvp_feed_channel_path stable)
source_dir="$site_dir/feed/$release_path"
channel_dir="$site_dir/feed/$channel_path"
channel_parent=$(dirname -- "$channel_dir")

[[ -d "$source_dir" ]] || {
  echo "cannot promote an unstaged immutable release: $source_dir" >&2
  exit 65
}
"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$source_dir"

mkdir -p -- "$channel_parent"
staging_dir=$(mktemp -d "$channel_parent/.stable-staging.XXXXXX")
previous_dir=
cleanup() {
  [[ -n "${staging_dir:-}" && -d "$staging_dir" ]] && rm -rf -- "$staging_dir"
  [[ -n "${previous_dir:-}" && -d "$previous_dir" ]] && rm -rf -- "$previous_dir"
  # An EXIT trap must preserve the successful promotion status even when there
  # was no staging or previous directory left to remove.
  return 0
}
trap cleanup EXIT

cp -a -- "$source_dir/." "$staging_dir/"
cat >"$staging_dir/release.json" <<EOF
{
  "publication_type": "mutable-channel",
  "channel": "stable",
  "feed_release": "$release",
  "source_release_path": "$release_path",
  "platform_slug": "$PLATFORM_SLUG",
  "platform_id": "$PLATFORM_ID",
  "architecture": "$ARCH",
  "index": "Packages.gz",
  "signature": "Packages.asc"
}
EOF

# The channel contains the rN index, both detached signatures and every IPK
# byte-for-byte.  Replacing it is therefore safe only after the staged copy
# has independently passed the same release validation as its source.
"$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$staging_dir"

if [[ -e "$channel_dir" ]]; then
  previous_dir=$(mktemp -d "$channel_parent/.stable-previous.XXXXXX")
  rmdir -- "$previous_dir"
  mv -- "$channel_dir" "$previous_dir"
fi
mv -- "$staging_dir" "$channel_dir"
staging_dir=

bash "$script_dir/verify-stable-channel.sh" --platform "$platform_slug"
TDVP_FEED_SITE_ROOT="$site_dir" bash "$script_dir/render-site-index.sh"
echo "promoted stable channel: $channel_dir <= $source_dir"
