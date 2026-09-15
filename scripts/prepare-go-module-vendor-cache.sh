#!/usr/bin/env bash
# Seed one reviewed Go package's deterministic vendor bundle before an offline
# feed build. This is intentionally a host-only source-cache operation: it
# creates no target payload and does not require a K230 SDK.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  echo "usage: $0 --package-dir <packages/name> [--cache <directory>] [--offline]" >&2
}

package_dir=
cache_root=
offline=${TDVP_SOURCE_CACHE_OFFLINE:-0}
while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-dir)
      [[ $# -ge 2 && -z "$package_dir" ]] || { usage; exit 64; }
      package_dir=$2
      shift 2
      ;;
    --cache)
      [[ $# -ge 2 && -z "$cache_root" ]] || { usage; exit 64; }
      cache_root=$2
      shift 2
      ;;
    --offline)
      offline=1
      shift
      ;;
    *)
      usage
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done
[[ -n "$package_dir" ]] || { usage; exit 64; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir=$(cd -- "$package_dir" && pwd)
[[ "$(dirname -- "$package_dir")" == "$repo_root/packages" ]] || {
  echo "Go module cache seed requires a direct packages/<name> directory: $package_dir" >&2
  exit 65
}
[[ -f "$package_dir/package.env" && ! -L "$package_dir/package.env" ]] || {
  echo "Go module cache seed is missing package.env: $package_dir" >&2
  exit 66
}
# package.env remains the reviewed recipe metadata and supplies the source
# archive name and source directory. source.lock independently validates every
# upstream and non-executable build input before this script touches the cache.
# shellcheck source=/dev/null
source "$package_dir/package.env"
[[ -n "${SOURCE_ARCHIVE:-}" && -n "${SOURCE_DIRECTORY:-}" ]] || {
  echo "Go module cache seed package lacks SOURCE_ARCHIVE or SOURCE_DIRECTORY: $package_dir" >&2
  exit 67
}

cache_root=${cache_root:-"$repo_root/.tdvp-source-cache"}
if [[ -e "$cache_root" || -L "$cache_root" ]]; then
  [[ -d "$cache_root" && ! -L "$cache_root" ]] || {
    echo "Go module cache seed cache path is unsafe: $cache_root" >&2
    exit 68
  }
else
  mkdir -p -- "$cache_root"
fi
cache_root=$(cd -- "$cache_root" && pwd -P)
export TDVP_SOURCE_CACHE_ROOT="$cache_root"
export TDVP_SOURCE_CACHE_OFFLINE="$offline"

# shellcheck source=../support/source-archive-library.sh
source "$repo_root/support/source-archive-library.sh"
# shellcheck source=../support/go-module-vendor-cache.sh
source "$repo_root/support/go-module-vendor-cache.sh"
tdvp_load_go_module_vendor_lock "$package_dir"

work_root=$(mktemp -d "${TMPDIR:-/tmp}/tdvp-go-vendor-seed.XXXXXX")
cleanup() {
  local rc=$?
  chmod -R u+w -- "$work_root" 2>/dev/null || true
  rm -rf -- "$work_root"
  exit "$rc"
}
trap cleanup EXIT

source_archive=$(tdvp_source_archive_locked_file "$package_dir" "$SOURCE_ARCHIVE")
tar -xzf "$source_archive" -C "$work_root"
source_root="$work_root/$SOURCE_DIRECTORY"
[[ -d "$source_root" && ! -L "$source_root" && -f "$source_root/go.mod" && -f "$source_root/go.sum" ]] || {
  echo "locked Go source archive did not unpack as expected: $source_root" >&2
  exit 69
}
go_binary=$(tdvp_prepare_locked_go_host_toolchain "$package_dir" "$work_root")
vendor_cache=$(tdvp_prepare_go_module_vendor_cache "$source_root" "$go_binary" "$work_root")
printf 'Go vendor cache ready: %s\n' "$vendor_cache"
