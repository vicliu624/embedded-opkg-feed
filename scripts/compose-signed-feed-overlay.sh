#!/usr/bin/env bash
# Compose an unsigned next snapshot from a signed immutable base and one
# provider-aware incremental overlay.  The overlay wins by package name; base
# packages absent from it are retained byte-for-byte.  Signing the result is a
# separate protected-host operation.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
base_feed=
overlay_feed=
output_feed=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --base)
      [[ $# -ge 2 ]] || { echo '--base needs a value' >&2; exit 64; }
      base_feed=$2
      shift 2
      ;;
    --overlay)
      [[ $# -ge 2 ]] || { echo '--overlay needs a value' >&2; exit 64; }
      overlay_feed=$2
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo '--output needs a value' >&2; exit 64; }
      output_feed=$2
      shift 2
      ;;
    *) echo "unexpected argument: $1" >&2; exit 64 ;;
  esac
done
[[ -n "$platform_slug" && -n "$base_feed" && -n "$overlay_feed" && -n "$output_feed" ]] || {
  echo "usage: $0 --platform <platform-slug> --base <signed-feed> --overlay <unsigned-feed> --output <new-feed>" >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
base_feed=$(cd -- "$base_feed" && pwd)
overlay_feed=$(cd -- "$overlay_feed" && pwd)
[[ ! -e "$output_feed" ]] || { echo "refusing to replace composition output: $output_feed" >&2; exit 65; }
for tool in awk cp install sort; do
  command -v "$tool" >/dev/null || { echo "required tool not found: $tool" >&2; exit 65; }
done

# The base is a public, immutable, signed release.  Do not accept an arbitrary
# directory as the foundation for a new stable channel.
bash "$script_dir/verify-feed.sh" --require-signature --platform "$platform_slug" "$base_feed"
bash "$script_dir/verify-feed.sh" --platform "$platform_slug" "$overlay_feed"

declare -A base_file=()
declare -A overlay_file=()
declare -A selected_file_owner=()

read_index() {
  local index=$1 map_name=$2
  local -n destination=$map_name
  local package filename
  while IFS=$'\t' read -r package filename; do
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || { echo "invalid Package in $index: $package" >&2; exit 66; }
    [[ "$filename" =~ ^[A-Za-z0-9+._-]+\.ipk$ ]] || { echo "invalid Filename in $index: $filename" >&2; exit 66; }
    [[ -z ${destination[$package]:-} ]] || { echo "duplicate Package in $index: $package" >&2; exit 66; }
    destination[$package]=$filename
  done < <(
    awk '
      /^Package: / { package=$2 }
      /^Filename: / { filename=$2 }
      /^$/ {
        if (package != "" || filename != "") {
          if (package == "" || filename == "") exit 1
          print package "\t" filename
        }
        package=filename=""
      }
      END {
        if (package != "" || filename != "") {
          if (package == "" || filename == "") exit 1
          print package "\t" filename
        }
      }
    ' "$index"
  ) || { echo "malformed Packages index: $index" >&2; exit 66; }
}

read_index "$base_feed/Packages" base_file
read_index "$overlay_feed/Packages" overlay_file
[[ ${#base_file[@]} -gt 0 && ${#overlay_file[@]} -gt 0 ]] || { echo 'feed input is empty' >&2; exit 66; }

mkdir -p -- "$output_feed"
copy_selected_package() {
  local source_dir=$1 package=$2 filename=$3
  local destination="$output_feed/$filename"
  [[ -f "$source_dir/$filename" ]] || { echo "missing package payload for $package: $source_dir/$filename" >&2; exit 67; }
  if [[ -n ${selected_file_owner[$filename]:-} ]]; then
    echo "package filename collision: $filename ($package and ${selected_file_owner[$filename]})" >&2
    exit 68
  fi
  install -m 0644 "$source_dir/$filename" "$destination"
  selected_file_owner[$filename]=$package
}

# Retain every base package except a package explicitly superseded by the
# overlay.  Sorting makes composition independent of index ordering.
while IFS= read -r package; do
  [[ -n ${overlay_file[$package]:-} ]] && continue
  copy_selected_package "$base_feed" "$package" "${base_file[$package]}"
done < <(printf '%s\n' "${!base_file[@]}" | LC_ALL=C sort)
while IFS= read -r package; do
  copy_selected_package "$overlay_feed" "$package" "${overlay_file[$package]}"
done < <(printf '%s\n' "${!overlay_file[@]}" | LC_ALL=C sort)

bash "$script_dir/make-index.sh" "$output_feed"
bash "$script_dir/verify-feed.sh" --platform "$platform_slug" "$output_feed"
printf 'composed unsigned feed: %s base=%d overlay=%d output=%d\n' \
  "$output_feed" "${#base_file[@]}" "${#overlay_file[@]}" "${#selected_file_owner[@]}"
