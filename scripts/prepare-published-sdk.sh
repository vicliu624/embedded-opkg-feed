#!/usr/bin/env bash
# Fetch immutable release inputs and verify before executing any SDK tool.
set -Eeuo pipefail
[[ $# == 2 ]] || { echo 'usage: prepare-published-sdk.sh <cache> <new-directory>' >&2; exit 64; }
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/platforms/tdvp-k230-r1/platform.env"
cache=$(mkdir -p -- "$1" && cd -- "$1" && pwd)
destination=$2
[[ ! -e "$destination" ]] || { echo "destination already exists: $destination" >&2; exit 65; }
fetch() {
  local name=$1 digest=$2 path="$cache/$1"
  if [[ ! -f "$path" ]]; then
    curl --fail --location --proto '=https' --tlsv1.2 --retry 3 \
      --output "$path.part" "$SDK_RELEASE_URL/$name"
    printf '%s  %s\n' "$digest" "$path.part" | sha256sum -c -
    mv -- "$path.part" "$path"
  fi
  printf '%s  %s\n' "$digest" "$path" | sha256sum -c -
}
fetch "$SDK_ARCHIVE" "$SDK_ARCHIVE_SHA256"
fetch tdvp-sdk-manifest.json "$SDK_MANIFEST_SHA256"
fetch "$SDK_IMAGE_ARCHIVE" "$SDK_IMAGE_SHA256"
fetch tdvp-image-base.json "$IMAGE_OWNERSHIP_MANIFEST_SHA256"
mkdir -p -- "$destination"
destination=$(cd -- "$destination" && pwd)
tar -xzf "$cache/$SDK_ARCHIVE" -C "$destination"
sdk="$destination/tdvp-sdk"
cmp "$cache/tdvp-sdk-manifest.json" "$sdk/tdvp-sdk-manifest.json"
cmp "$cache/tdvp-image-base.json" "$sdk/metadata/tdvp-image-base.json"
python3 "$sdk/verify-sdk.py" "$sdk" --smoke
python3 "$repo_root/scripts/verify-package-sdk.py" "$sdk" --host-tools
python3 "$repo_root/scripts/extract-published-rootfs.py" \
  "$cache/$SDK_IMAGE_ARCHIVE" "$sdk/metadata/tdvp-image-base.json" "$destination/target"
printf 'published SDK ready: %s\n' "$sdk"
