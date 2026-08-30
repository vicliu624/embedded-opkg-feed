#!/usr/bin/env bash
# Prove the reverse side of the composable-feed contract: every non-ABI
# dynamically linked object already present in the firmware runtime locations
# has one, and only one, byte-identical payload owner in this feed release.
#
# verify-runtime-closure.sh checks that feed packages declare everything they
# need.  This script catches the opposite class of regression: a library or
# dlopen module can remain in the base target (for example under usr/libexec)
# without ever being promoted to a reusable package.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 5 || "$1" != '--platform' || "$3" != '--base-root' ]]; then
  echo "usage: $0 --platform <platform-slug> --base-root <target-root> <feed-directory>" >&2
  exit 64
fi

platform_slug=$2
base_root=$(cd -- "$4" && pwd)
feed_dir=$(cd -- "$5" && pwd)
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

[[ -d "$base_root/usr/lib" ]] || {
  echo "base target root has no usr/lib: $base_root" >&2
  exit 65
}
[[ -s "$feed_dir/Packages" ]] || {
  echo "feed index is missing: $feed_dir/Packages" >&2
  exit 66
}

readelf_tool=${TDVP_READELF:-}
if [[ -z "$readelf_tool" ]]; then
  candidate=${TDVP_SDK_ROOT:-}/bin/riscv64-unknown-linux-gnu-readelf
  if [[ -x "$candidate" ]]; then
    readelf_tool=$candidate
  else
    readelf_tool=$(command -v readelf || true)
  fi
fi
[[ -n "$readelf_tool" ]] || {
  echo 'no readelf tool is available for runtime coverage validation' >&2
  exit 67
}

declare -A abi_soname=()
seed_manifest="$repo_root/platforms/$platform_slug/seed-packages.tsv"
[[ -s "$seed_manifest" ]] || {
  echo "missing base seed package manifest: $seed_manifest" >&2
  exit 68
}
while IFS='|' read -r seed_package seed_version seed_description seed_sonames; do
  seed_sonames=${seed_sonames%$'\r'}
  [[ -n "$seed_package" && "$seed_package" != \#* ]] || continue
  [[ -n "$seed_version" && -n "$seed_description" && -n "$seed_sonames" ]] || {
    echo "invalid base seed manifest record: $seed_package" >&2
    exit 69
  }
  IFS=',' read -r -a sonames <<< "$seed_sonames"
  for soname in "${sonames[@]}"; do
    [[ -n "$soname" ]] && abi_soname[$soname]=1
  done
done <"$seed_manifest"

read_control_field() {
  local control=$1
  local field=$2
  awk -F': ' -v field="$field" '$1 == field { print substr($0, length(field) + 3); exit }' "$control"
}

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

declare -A package_archive=()
declare -A package_root=()
declare -A runtime_path_owner=()
while IFS= read -r ipk; do
  control="$work_root/$(basename "$ipk").control"
  ar p "$ipk" control.tar.gz | tar -xOz -f - ./control >"$control"
  package=$(read_control_field "$control" Package)
  [[ -n "$package" ]] || {
    echo "package control is missing Package: $ipk" >&2
    exit 70
  }
  [[ -z "${package_archive[$package]:-}" ]] || {
    echo "duplicate package archive name in feed: $package" >&2
    exit 71
  }
  package_archive[$package]=$ipk
  payload_root="$work_root/payload/$package"
  mkdir -p -- "$payload_root"
  # Extract once rather than hashing each archive member through tar -xO.
  # GNU tar restores hard links during extraction; tar -xO emits no bytes for
  # a hard-link record, which would falsely report Mesa's swrast pair (and
  # any future deduplicated runtime object) as a content mismatch.
  ar p "$ipk" data.tar.gz | tar -xzf - -C "$payload_root"
  package_root[$package]=$payload_root

  # Feed data archives retain the leading ./ produced by tar -C root -czf.
  # Only library runtime directories participate in this ownership audit;
  # application data may legitimately be regenerated from the same source.
  while IFS= read -r archive_path; do
    relative=${archive_path#./}
    case "$relative" in
      usr/lib/*|usr/libexec/*|usr/local/lib/*|usr/local/libexec/*)
        [[ -n "$relative" && "$relative" != */ ]] || continue
        existing=${runtime_path_owner[$relative]:-}
        [[ -z "$existing" || "$existing" == "$package" ]] || {
          echo "runtime path /$relative is supplied by both $existing and $package" >&2
          exit 72
        }
        runtime_path_owner[$relative]=$package
        ;;
    esac
  done < <(ar p "$ipk" data.tar.gz | tar -tzf -)
done < <(find "$feed_dir" -maxdepth 1 -type f -name '*.ipk' -print | LC_ALL=C sort)

[[ ${#package_archive[@]} -gt 0 ]] || {
  echo "feed has no IPKs: $feed_dir" >&2
  exit 73
}

is_dynamic_elf() {
  "$readelf_tool" -d "$1" 2>/dev/null | grep -q 'Dynamic section'
}

elf_soname() {
  "$readelf_tool" -d "$1" 2>/dev/null |
    sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p' | head -n 1 || true
}

# /usr/local/lib is deliberately part of the audit even though generated
# runtime packages are not allowed to install there.  This makes an accidental
# custom-library install fail the release rather than becoming an invisible
# base-image dependency.  TDVP-owned shared objects belong under /usr/lib.
runtime_roots=("$base_root/usr/lib")
[[ -d "$base_root/usr/libexec" ]] && runtime_roots+=("$base_root/usr/libexec")
[[ -d "$base_root/usr/local/lib" ]] && runtime_roots+=("$base_root/usr/local/lib")
[[ -d "$base_root/usr/local/libexec" ]] && runtime_roots+=("$base_root/usr/local/libexec")
checked=0
while IFS= read -r -d '' runtime_file; do
  is_dynamic_elf "$runtime_file" || continue
  soname=$(elf_soname "$runtime_file")
  [[ -n "$soname" && -n "${abi_soname[$soname]:-}" ]] && continue

  relative=${runtime_file#"$base_root/"}
  owner=${runtime_path_owner[$relative]:-}
  [[ -n "$owner" ]] || {
    echo "base runtime object /$relative has no feed owner" >&2
    exit 74
  }

  payload_file="${package_root[$owner]}/$relative"
  if [[ ! -f "$payload_file" ]]; then
    echo "owner $owner does not extract a regular runtime file at /$relative" >&2
    exit 75
  fi
  payload_sha=$(sha256sum "$payload_file" | awk '{print $1}')
  target_sha=$(sha256sum "$runtime_file" | awk '{print $1}')
  [[ "$target_sha" == "$payload_sha" ]] || {
    echo "feed owner $owner does not preserve /$relative byte-for-byte" >&2
    exit 76
  }
  checked=$((checked + 1))
done < <(find "${runtime_roots[@]}" -type f -print0 | LC_ALL=C sort -z)

[[ "$checked" -gt 0 ]] || {
  echo "no non-ABI dynamic runtime objects found below ${runtime_roots[*]}" >&2
  exit 77
}
echo "target runtime coverage passed: $checked non-ABI dynamic objects in $feed_dir"
