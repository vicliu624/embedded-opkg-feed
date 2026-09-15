#!/usr/bin/env bash
# Ensure a full-desktop feed never retains a package that forces opkg to
# install a canonical runtime already supplied by a tdvp-image-* owner.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
provider_map=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --provider-map)
      [[ $# -ge 2 ]] || { echo '--provider-map needs a value' >&2; exit 64; }
      provider_map=$2
      shift 2
      ;;
    *)
      [[ -z ${feed_dir:-} ]] || { echo "unexpected argument: $1" >&2; exit 64; }
      feed_dir=$1
      shift
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$provider_map" && -n ${feed_dir:-} ]] || {
  echo "usage: $0 --platform <platform-slug> --provider-map <package|tdvp-image-owner.tsv> <feed-directory>" >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"
feed_dir=$(cd -- "$feed_dir" && pwd)
[[ -s "$provider_map" ]] || { echo "missing provider map: $provider_map" >&2; exit 65; }
[[ -s "$feed_dir/Packages" ]] || { echo "missing Packages index: $feed_dir/Packages" >&2; exit 65; }
for tool in ar tar; do
  command -v "$tool" >/dev/null || { echo "required tool not found: $tool" >&2; exit 65; }
done

declare -A image_provider=()
while IFS='|' read -r package provider; do
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || { echo "invalid provider-map package: $package" >&2; exit 66; }
  [[ "$provider" =~ ^tdvp-image-[a-z0-9][a-z0-9+.-]*$ ]] || { echo "invalid image provider for $package: $provider" >&2; exit 66; }
  [[ -z ${image_provider[$package]:-} || ${image_provider[$package]} == "$provider" ]] || {
    echo "ambiguous image provider mapping for $package" >&2
    exit 66
  }
  image_provider[$package]=$provider
done <"$provider_map"
[[ ${#image_provider[@]} -gt 0 ]] || { echo 'provider map is empty' >&2; exit 66; }

control_archive=$(mktemp)
control_file=$(mktemp)
trap 'rm -f -- "$control_archive" "$control_file"' EXIT
errors=0
while IFS= read -r ipk; do
  ar p "$ipk" control.tar.gz >"$control_archive"
  tar -xOzf "$control_archive" ./control >"$control_file"
  package=$(sed -n 's/^Package: //p' "$control_file")
  depends=$(sed -n 's/^Depends: //p' "$control_file")
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || { echo "invalid package control in $ipk" >&2; exit 67; }
  [[ "$depends" == *"$ABI_PACKAGE (= $ABI_VERSION)"* ]] || { echo "missing ABI dependency in $package" >&2; exit 67; }
  [[ -n "$depends" ]] || continue

  IFS=',' read -r -a groups <<<"$depends"
  for group in "${groups[@]}"; do
    primary=$(sed -E 's/^[[:space:]]*([a-z0-9+.-]+).*/\1/' <<<"$group")
    provider=${image_provider[$primary]:-}
    [[ -n "$provider" ]] || continue
    if [[ ! "$group" =~ (^|[[:space:]])\|[[:space:]]*$provider([[:space:]]|$) ]]; then
      printf '%s: mapped runtime dependency lacks image-provider alternative: %s (expected %s)\n' \
        "$package" "$group" "$provider" >&2
      errors=1
    fi
  done
done < <(find "$feed_dir" -maxdepth 1 -type f -name '*.ipk' -print | LC_ALL=C sort)

[[ "$errors" -eq 0 ]] || exit 68
echo "image-provider dependency alternatives verified: $feed_dir"
