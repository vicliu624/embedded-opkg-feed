#!/usr/bin/env bash
# Build all reviewed package recipes for one explicit platform.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--output' ]]; then
  echo "usage: $0 --platform <platform-slug> --output <output-root>" >&2
  exit 64
fi

platform_slug=$2
output_root=$4
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
platform_file="$repo_root/platforms/$platform_slug/platform.env"
[[ -f "$platform_file" ]] || { echo "unknown platform: $platform_slug" >&2; exit 65; }
# shellcheck source=/dev/null
source "$platform_file"

feed_dir="$output_root/$PLATFORM_ID/$ARCH"
if [[ -e "$feed_dir/Packages" || -e "$feed_dir/Packages.gz" ]]; then
  echo "refusing to overwrite an existing immutable feed: $feed_dir" >&2
  exit 66
fi
mkdir -p -- "$feed_dir"

found=0
while IFS= read -r package_env; do
  found=1
  package_dir=$(dirname -- "$package_env")
  # Invoke recipes through Bash instead of depending on an executable bit.
  # This keeps a recipe buildable after a Windows checkout, where Git may not
  # preserve POSIX file modes for newly added shell scripts.
  if [[ -f "$package_dir/build.sh" ]]; then
    bash "$package_dir/build.sh" --platform "$platform_slug" --sdk-root "${TDVP_SDK_ROOT:-}"
  fi
  "$script_dir/build-ipk.sh" --platform "$platform_slug" "$package_dir" "$feed_dir"
done < <(find "$repo_root/packages" -mindepth 2 -maxdepth 2 -name package.env -type f -print | LC_ALL=C sort)

[[ "$found" -eq 1 ]] || { echo 'no package.env recipes found under packages/' >&2; exit 67; }
"$script_dir/make-index.sh" "$feed_dir"
"$script_dir/verify-feed.sh" --platform "$platform_slug" "$feed_dir"
echo "feed ready for offline signing: $feed_dir"
