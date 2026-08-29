#!/usr/bin/env bash
# Prove that every runtime ELF dependency is either supplied by the immutable
# firmware rootfs or by an explicit dependency in this very feed.  This makes
# a package's control metadata describe the actual dynamic-linker closure.
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

[[ -d "$base_root" ]] || { echo "base target root is missing: $base_root" >&2; exit 65; }
[[ -s "$feed_dir/Packages" ]] || { echo "feed index is missing: $feed_dir/Packages" >&2; exit 66; }

readelf_tool=${TDVP_READELF:-}
if [[ -z "$readelf_tool" ]]; then
  candidate=${TDVP_SDK_ROOT:-}/bin/riscv64-unknown-linux-gnu-readelf
  if [[ -x "$candidate" ]]; then
    readelf_tool=$candidate
  else
    readelf_tool=$(command -v readelf || true)
  fi
fi
[[ -n "$readelf_tool" ]] || { echo 'no readelf tool is available for runtime closure validation' >&2; exit 67; }

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

declare -A package_root=()
declare -A package_depends=()
declare -A soname_owner=()
declare -A base_soname_owner=()

seed_manifest="$repo_root/platforms/$platform_slug/seed-packages.tsv"
[[ -s "$seed_manifest" ]] || {
  echo "missing base seed package manifest: $seed_manifest" >&2
  exit 68
}
while IFS='|' read -r seed_package seed_version seed_description seed_sonames; do
  [[ -n "$seed_package" && "$seed_package" != \#* ]] || continue
  [[ -n "$seed_version" && -n "$seed_description" && -n "$seed_sonames" ]] || {
    echo "invalid base seed manifest record: $seed_package" >&2
    exit 69
  }
  IFS=',' read -r -a parsed_sonames <<< "$seed_sonames"
  for soname in "${parsed_sonames[@]}"; do
    [[ -n "$soname" ]] || continue
    [[ -z "${base_soname_owner[$soname]:-}" ]] || {
      echo "base seed manifest assigns $soname twice" >&2
      exit 70
    }
    base_soname_owner[$soname]=$seed_package
  done
done <"$seed_manifest"

read_control_field() {
  local control=$1
  local field=$2
  awk -F': ' -v field="$field" '$1 == field { print substr($0, length(field) + 3); exit }' "$control"
}

dependency_contains() {
  local dependencies=$1
  local wanted=$2
  local item name
  IFS=',' read -r -a items <<< "$dependencies"
  for item in "${items[@]}"; do
    name=$(printf '%s' "$item" | sed -E 's/^[[:space:]]*([^[:space:]<(=]+).*/\1/')
    [[ "$name" == "$wanted" ]] && return 0
  done
  return 1
}

while IFS= read -r ipk; do
  archive="$work_root/$(basename "$ipk" .ipk)"
  mkdir -p -- "$archive/control" "$archive/root"
  ar p "$ipk" control.tar.gz | tar -xzf - -C "$archive/control"
  ar p "$ipk" data.tar.gz | tar -xzf - -C "$archive/root"
  package=$(read_control_field "$archive/control/control" Package)
  depends=$(read_control_field "$archive/control/control" Depends)
  [[ -n "$package" ]] || { echo "package control is missing Package: $ipk" >&2; exit 71; }
  [[ -z "${package_root[$package]:-}" ]] || { echo "duplicate package in feed: $package" >&2; exit 72; }
  package_root[$package]="$archive/root"
  package_depends[$package]=$depends
done < <(find "$feed_dir" -maxdepth 1 -type f -name '*.ipk' -print | LC_ALL=C sort)

for package in "${!package_root[@]}"; do
  while IFS= read -r elf; do
    # A library may expose several symlink names.  Its dynamic linker SONAME
    # is authoritative; files without one are still checked as consumers.
    while IFS= read -r soname; do
      [[ -n "$soname" ]] || continue
      [[ -z "${soname_owner[$soname]:-}" || "${soname_owner[$soname]}" == "$package" ]] || {
        echo "SONAME $soname is supplied by both ${soname_owner[$soname]} and $package" >&2
        exit 73
      }
      soname_owner[$soname]=$package
    done < <("$readelf_tool" -d "$elf" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')
  done < <(find "${package_root[$package]}" -type f -perm -u+x -o -type f -name '*.so*')
done

base_has_soname() {
  local soname=$1
  find "$base_root/lib" "$base_root/usr/lib" -maxdepth 2 \( -type f -o -type l \) \
    -name "$soname" -print -quit 2>/dev/null | grep -q .
}

for package in "${!package_root[@]}"; do
  while IFS= read -r elf; do
    while IFS= read -r soname; do
      [[ -n "$soname" ]] || continue
      if base_has_soname "$soname"; then
        base_owner=${base_soname_owner[$soname]:-}
        [[ -n "$base_owner" ]] || {
          echo "$package needs base SONAME $soname, but it is absent from the seed manifest" >&2
          exit 74
        }
        dependency_contains "${package_depends[$package]}" "$base_owner" || {
          echo "$package needs base SONAME $soname from $base_owner but does not declare it" >&2
          exit 75
        }
        continue
      fi
      owner=${soname_owner[$soname]:-}
      [[ -n "$owner" ]] || {
        echo "$package needs $soname, but it is not supplied by the base image or feed" >&2
        exit 76
      }
      [[ "$owner" == "$package" ]] && continue
      dependency_contains "${package_depends[$package]}" "$owner" || {
        echo "$package needs $soname from $owner but does not declare Depends: $owner" >&2
        exit 77
      }
    done < <("$readelf_tool" -d "$elf" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
    if "$readelf_tool" -d "$elf" 2>/dev/null | grep -Eq '\((RPATH|RUNPATH)\)'; then
      echo "$package payload contains an ELF RPATH/RUNPATH: $elf" >&2
      exit 78
    fi
  done < <(find "${package_root[$package]}" -type f -perm -u+x -o -type f -name '*.so*')
done

echo "runtime dependency closure passed: $feed_dir"
