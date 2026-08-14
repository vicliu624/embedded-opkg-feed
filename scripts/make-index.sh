#!/usr/bin/env bash
# Generate a deterministic opkg Packages and Packages.gz index from .ipk files.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <feed-directory>" >&2
  exit 64
fi

feed_dir=$(cd -- "$1" && pwd)
for tool in ar gzip md5sum sha256sum tar; do
  command -v "$tool" >/dev/null || {
    echo "required index tool not found: $tool" >&2
    exit 65
  }
done

if [[ -e "$feed_dir/Packages" || -e "$feed_dir/Packages.gz" ]]; then
  echo "refusing to overwrite an existing index in $feed_dir" >&2
  exit 66
fi

packages_file="$feed_dir/Packages"
found=0
while IFS= read -r ipk; do
  found=1
  control_archive=$(mktemp)
  control_file=$(mktemp)
  trap 'rm -f -- "$control_archive" "$control_file"' EXIT

  ar p "$ipk" control.tar.gz >"$control_archive"
  tar -xOzf "$control_archive" ./control >"$control_file"

  cat "$control_file" >>"$packages_file"
  printf 'Filename: %s\n' "$(basename -- "$ipk")" >>"$packages_file"
  printf 'Size: %s\n' "$(wc -c <"$ipk" | tr -d ' ')" >>"$packages_file"
  printf 'MD5Sum: %s\n' "$(md5sum "$ipk" | awk '{print $1}')" >>"$packages_file"
  printf 'SHA256sum: %s\n\n' "$(sha256sum "$ipk" | awk '{print $1}')" >>"$packages_file"
  rm -f -- "$control_archive" "$control_file"
  trap - EXIT
done < <(find "$feed_dir" -maxdepth 1 -type f -name '*.ipk' -print | LC_ALL=C sort)

if [[ "$found" -eq 0 ]]; then
  rm -f -- "$packages_file"
  echo "no .ipk files found in $feed_dir" >&2
  exit 67
fi

gzip -n -9 -c "$packages_file" >"$feed_dir/Packages.gz"
echo "generated $packages_file and $feed_dir/Packages.gz"
