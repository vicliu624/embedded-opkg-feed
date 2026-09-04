#!/usr/bin/env bash
# Fetch only source artifacts declared by a validated source.lock into a
# content-addressed cache. Recipes consume this cache; they never fetch a
# mutable upstream binary themselves during the release build.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  echo "usage: $0 --cache <directory> --package-dir <packages/name> [--offline] [--ca-bundle <pem-file>]" >&2
}

cache_root=
package_dir=
ca_bundle=
offline=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      [[ -z "$cache_root" ]] || { echo '--cache may be supplied once' >&2; exit 64; }
      cache_root=$2
      shift 2
      ;;
    --package-dir)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      [[ -z "$package_dir" ]] || { echo '--package-dir may be supplied once' >&2; exit 64; }
      package_dir=$2
      shift 2
      ;;
    --offline)
      offline=1
      shift
      ;;
    --ca-bundle)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      [[ -z "$ca_bundle" ]] || { echo '--ca-bundle may be supplied once' >&2; exit 64; }
      ca_bundle=$2
      shift 2
      ;;
    *)
      usage
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done
[[ -n "$cache_root" && -n "$package_dir" ]] || { usage; exit 64; }

# An explicitly supplied CA bundle is a host-side trust repair for old build
# hosts. It never relaxes HTTPS verification (notably, --insecure is never
# accepted) and the immutable artifact hash remains the final cache gate.
if [[ -n "$ca_bundle" ]]; then
  [[ -f "$ca_bundle" && ! -L "$ca_bundle" ]] || {
    echo "CA bundle must be a regular, non-symlink file: $ca_bundle" >&2
    exit 71
  }
  grep -Fq -- '-----BEGIN CERTIFICATE-----' "$ca_bundle" || {
    echo "CA bundle contains no PEM certificate: $ca_bundle" >&2
    exit 71
  }
  ca_bundle=$(cd -P -- "$(dirname -- "$ca_bundle")" && pwd)/$(basename -- "$ca_bundle")
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cache_root=$(mkdir -p -- "$cache_root" && cd -- "$cache_root" && pwd)
package_dir=$(cd -- "$package_dir" && pwd)
temporary=
cleanup_download() {
  [[ -z "$temporary" ]] || rm -f -- "$temporary"
}
trap cleanup_download EXIT

mapfile -t artifacts < <(bash "$script_dir/verify-source-lock.sh" --package-dir "$package_dir" --emit-artifacts)
[[ ${#artifacts[@]} -gt 0 ]] || { echo "no source artifacts declared for $package_dir" >&2; exit 65; }

for artifact in "${artifacts[@]}"; do
  IFS=$'\t' read -r url filename expected_sha256 <<<"$artifact"
  destination_dir="$cache_root/sha256/$expected_sha256"
  destination="$destination_dir/$filename"
  mkdir -p -- "$destination_dir"
  if [[ -e "$destination" || -L "$destination" ]]; then
    [[ -f "$destination" && ! -L "$destination" ]] || {
      echo "unsafe source-cache entry: $destination" >&2
      exit 66
    }
  else
    [[ "$offline" -eq 0 ]] || {
      echo "offline source cache miss: $filename ($expected_sha256)" >&2
      exit 67
    }
    command -v curl >/dev/null || { echo 'curl is required to fetch a source-cache miss' >&2; exit 68; }
    temporary=$(mktemp "$destination_dir/.${filename}.download.XXXXXX")
    curl_args=(--fail --location --proto '=https' --tlsv1.2 --retry 3)
    [[ -z "$ca_bundle" ]] || curl_args+=(--cacert "$ca_bundle")
    curl "${curl_args[@]}" --output "$temporary" "$url"
    actual_sha256=$(sha256sum "$temporary" | awk '{print $1}')
    [[ "$actual_sha256" == "$expected_sha256" ]] || {
      echo "source-cache hash mismatch for $filename: expected $expected_sha256, got $actual_sha256" >&2
      exit 69
    }
    chmod 0444 -- "$temporary"
    mv -- "$temporary" "$destination"
    temporary=
  fi
  actual_sha256=$(sha256sum "$destination" | awk '{print $1}')
  [[ "$actual_sha256" == "$expected_sha256" ]] || {
    echo "corrupt source-cache entry: $destination" >&2
    exit 70
  }
  printf 'source cache ready: %s\n' "$destination" >&2
done
