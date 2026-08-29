#!/usr/bin/env bash
# Materialise the reusable runtime half of a TDVP feed directly from the
# completed, locked Buildroot target.  This does not compile or relink any
# library: it turns the exact already-built runtime into independent IPKs,
# derives their real ELF dependency graph, and proves every non-ABI SONAME has
# one owner in the same immutable release.
set -Eeuo pipefail
IFS=$'\n\t'

platform_slug=
target_root=
output_dir=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      [[ $# -ge 2 ]] || { echo '--platform needs a value' >&2; exit 64; }
      platform_slug=$2
      shift 2
      ;;
    --target-root)
      [[ $# -ge 2 ]] || { echo '--target-root needs a value' >&2; exit 64; }
      target_root=$2
      shift 2
      ;;
    --output)
      [[ $# -ge 2 ]] || { echo '--output needs a value' >&2; exit 64; }
      output_dir=$2
      shift 2
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

[[ -n "$platform_slug" && -n "$target_root" && -n "$output_dir" ]] || {
  echo 'usage: build-runtime-catalog.sh --platform <platform> --target-root <Buildroot-target> --output <feed-dir>' >&2
  exit 64
}

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

target_root=$(cd -- "$target_root" && pwd)
output_dir=$(mkdir -p -- "$output_dir" && cd -- "$output_dir" && pwd)
[[ -d "$target_root/usr/lib" ]] || { echo "target root has no usr/lib: $target_root" >&2; exit 65; }

readelf_tool=${TDVP_READELF:-}
if [[ -z "$readelf_tool" && -n "${TDVP_SDK_ROOT:-}" ]]; then
  readelf_tool="$TDVP_SDK_ROOT/bin/riscv64-unknown-linux-gnu-readelf"
fi
[[ -n "$readelf_tool" && -x "$readelf_tool" ]] || {
  echo 'set TDVP_READELF or TDVP_SDK_ROOT to the matching K230 readelf tool' >&2
  exit 66
}

runtime_version=${RUNTIME_CATALOG_VERSION:-"${ABI_VERSION}-runtime.1"}
data_manifest="$repo_root/platforms/$platform_slug/runtime-data-packages.tsv"
extra_owner_manifest="$repo_root/platforms/$platform_slug/extra-runtime-owners.tsv"
[[ -f "$data_manifest" ]] || { echo "missing runtime data manifest: $data_manifest" >&2; exit 67; }
[[ -f "$extra_owner_manifest" ]] || { echo "missing extra runtime owner manifest: $extra_owner_manifest" >&2; exit 68; }

work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT
owner_map="$output_dir/.tdvp-runtime-owners.tsv"
ownership_report="$output_dir/.tdvp-runtime-ownership.tsv"
: >"$owner_map"
: >"$ownership_report"

is_abi_soname() {
  case "$1" in
    ld-linux-riscv32-ilp32.so.1|ld-linux-riscv32-ilp32d.so.1|ld-linux-riscv64-lp64.so.1|ld-linux-riscv64-lp64d.so.1|libc.so.6|libdl.so.2|libm.so.6|libpthread.so.0|librt.so.1|libgcc_s.so.1|libstdc++.so.6)
      return 0
      ;;
    *) return 1 ;;
  esac
}

package_from_soname() {
  local soname=$1
  printf '%s' "$soname" | tr '[:upper:]' '[:lower:]' | sed -E \
    -e 's/\.so([.]|$)/-/g' \
    -e 's/[^a-z0-9+.-]+/-/g' \
    -e 's/-+/-/g' \
    -e 's/-$//'
}

soname_of() {
  # A target /usr/lib directory can legitimately contain helper scripts next
  # to ELF objects (for example libstdc++'s gdb Python helper).  Those are not
  # runtime libraries and must not make the complete catalogue scan fail under
  # pipefail.
  "$readelf_tool" -d "$1" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p' | head -n 1 || true
}

declare -A soname_file=()
declare -A soname_package=()
declare -A package_soname=()

while IFS= read -r -d '' library; do
  soname=$(soname_of "$library")
  [[ -n "$soname" ]] || continue
  is_abi_soname "$soname" && continue
  [[ -z "${soname_file[$soname]:-}" ]] || {
    echo "target contains duplicate real SONAME providers: $soname" >&2
    exit 69
  }
  package=$(package_from_soname "$soname")
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || {
    echo "cannot derive a valid package name from SONAME: $soname" >&2
    exit 70
  }
  [[ -z "${package_soname[$package]:-}" || "${package_soname[$package]}" == "$soname" ]] || {
    echo "SONAME package-name collision: ${package_soname[$package]} and $soname -> $package" >&2
    exit 71
  }
  soname_file[$soname]=$library
  soname_package[$soname]=$package
  package_soname[$package]=$soname
# Do not restrict this to lib*.so*: compatibility dynamic loaders such as
# ld-linux-riscv32-* also have a SONAME and are non-ABI runtime objects unless
# explicitly listed in the narrow ABI seed.
done < <(find "$target_root/usr/lib" -maxdepth 1 -type f -name '*.so*' -print0 | LC_ALL=C sort -z)

[[ ${#soname_file[@]} -gt 0 ]] || { echo 'no non-ABI target SONAMEs found' >&2; exit 72; }

for soname in "${!soname_package[@]}"; do
  printf '%s|%s|%s\n' "$soname" "${soname_package[$soname]}" "$runtime_version" >>"$owner_map"
done

add_owner_map_record() {
  local soname=$1
  local package=$2
  local existing
  is_abi_soname "$soname" && return 0
  existing=$(awk -F'|' -v soname="$soname" '$1 == soname { print $2; exit }' "$owner_map")
  if [[ -n "$existing" && "$existing" != "$package" ]]; then
    echo "runtime owner conflict for $soname: $existing and $package" >&2
    exit 73
  fi
  [[ -n "$existing" ]] || printf '%s|%s|%s\n' "$soname" "$package" "$runtime_version" >>"$owner_map"
}

# Shared runtimes that are deliberately built outside the firmware target
# still participate in the same closure.  Their archived payload is reused by
# r3 rather than recompiling an already-published shared library.
while IFS='|' read -r soname package version; do
  soname=${soname%$'\r'}
  [[ -n "$soname" && "$soname" != \#* ]] || continue
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ && -n "$version" ]] || {
    echo "invalid extra runtime owner record: $soname" >&2
    exit 74
  }
  [[ -z "${soname_package[$soname]:-}" ]] || {
    echo "extra runtime owner duplicates target SONAME: $soname" >&2
    exit 75
  }
  printf '%s|%s|%s\n' "$soname" "$package" "$version" >>"$owner_map"
done <"$extra_owner_manifest"

# Some upstreams put private but dynamically linked helper libraries below a
# module directory (PulseAudio's libpulsecommon is the important example).
# They still need a single explicit owner so top-level runtimes can express an
# exact dependency.  Pre-register all SONAMEs belonging to a data/module
# package before building any IPK, including the catch-all module owner.  The
# planned-path set gives the catch-all selector the same ownership semantics as
# the later payload copy rather than assigning it a module claimed by Mesa,
# GTK, or another explicit package.
declare -A planned_data_paths=()
register_planned_data_file() {
  local source=$1
  local package=$2
  local allow_existing=$3
  local relative=${source#"$target_root"}
  if [[ -n "${planned_data_paths[$relative]:-}" ]]; then
    if [[ "$allow_existing" == 1 ]]; then
      return 1
    fi
    echo "runtime data selectors overlap: $relative (${planned_data_paths[$relative]}, $package)" >&2
    exit 76
  fi
  planned_data_paths[$relative]=$package
  return 0
}
while IFS='|' read -r package description selectors; do
  package=${package%$'\r'}
  [[ -n "$package" && "$package" != \#* ]] || continue
  IFS=',' read -r -a selector_list <<< "$selectors"
  for selector in "${selector_list[@]}"; do
    selector=$(printf '%s' "$selector" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    case "$selector" in
      @remaining-usr-lib)
        while IFS= read -r -d '' module; do
          register_planned_data_file "$module" "$package" 1 || continue
          soname=$(soname_of "$module")
          [[ -n "$soname" ]] && add_owner_map_record "$soname" "$package"
        done < <(find "$target_root/usr/lib" -mindepth 2 -type f -name '*.so*' -print0 | LC_ALL=C sort -z)
        ;;
      @remaining-usr-libexec)
        # Programs below /usr/libexec often load private helper libraries
        # (sudo's libsudo_util and policy modules are the current examples).
        # They are runtime objects just as much as a GTK or PulseAudio module,
        # so register their SONAMEs before automatic Depends are calculated.
        if [[ -d "$target_root/usr/libexec" ]]; then
          while IFS= read -r -d '' module; do
            register_planned_data_file "$module" "$package" 1 || continue
            soname=$(soname_of "$module")
            [[ -n "$soname" ]] && add_owner_map_record "$soname" "$package"
          done < <(find "$target_root/usr/libexec" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
        fi
        ;;
      @remaining-usr-share)
        while IFS= read -r -d '' data_file; do
          register_planned_data_file "$data_file" "$package" 1 || continue
        done < <(find "$target_root/usr/share" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
        ;;
      *)
        shopt -s nullglob
        sources=("$target_root"$selector)
        shopt -u nullglob
        for source in "${sources[@]}"; do
          if [[ -d "$source" && ! -L "$source" ]]; then
            while IFS= read -r -d '' module; do
              register_planned_data_file "$module" "$package" 0
              soname=$(soname_of "$module")
              [[ -n "$soname" ]] && add_owner_map_record "$soname" "$package"
            done < <(find "$source" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
          elif [[ -f "$source" || -L "$source" ]]; then
            register_planned_data_file "$source" "$package" 0
            soname=$(soname_of "$source")
            [[ -n "$soname" ]] && add_owner_map_record "$soname" "$package"
          fi
        done
        ;;
    esac
  done
done <"$data_manifest"
LC_ALL=C sort -u -o "$owner_map" "$owner_map"

copy_path() {
  local source=$1
  local destination_root=$2
  local relative=${source#"$target_root"}
  local destination="$destination_root$relative"
  if [[ -d "$source" && ! -L "$source" ]]; then
    mkdir -p -- "$destination"
    cp -a -- "$source/." "$destination/"
  else
    mkdir -p -- "$(dirname -- "$destination")"
    cp -a -- "$source" "$destination"
  fi
}

declare -A claimed_paths=()
claim_path() {
  local source=$1
  local package=$2
  local relative=${source#"$target_root"}
  [[ -z "${claimed_paths[$relative]:-}" ]] || {
    echo "runtime catalogue path is owned twice: $relative (${claimed_paths[$relative]}, $package)" >&2
    exit 75
  }
  claimed_paths[$relative]=$package
  printf '%s|%s\n' "$package" "$relative" >>"$ownership_report"
}

build_generated_package() {
  local package=$1
  local description=$2
  local root=$3
  local package_dir="$work_root/$package"
  mkdir -p -- "$package_dir"
  cat >"$package_dir/package.env" <<EOF
PACKAGE='$package'
VERSION='$runtime_version'
PACKAGE_ARCH='$ARCH'
MAINTAINER='TDVP Device Team <devices@example.invalid>'
DESCRIPTION='$description'
SUPPORTED_PLATFORMS='$PLATFORM_SLUG'
PACKAGE_KIND='runtime'
PACKAGE_RELEASES='generated'
PACKAGE_DEPENDS=''
PACKAGE_BASE_OVERLAY='identical'
PACKAGE_AUTO_RUNTIME_DEPENDS=1
EOF
  mv -- "$root" "$package_dir/root"
  TDVP_FEED_BASE_ROOT="$target_root" \
  TDVP_RUNTIME_OWNER_MAP="$owner_map" \
  TDVP_READELF="$readelf_tool" \
    "$script_dir/build-ipk.sh" --platform "$platform_slug" "$package_dir" "$output_dir"
}

# First package every top-level non-ABI SONAME.  A package contains its real
# object plus the exact loader and development symlinks that share its SONAME
# prefix, so no other package can claim that library path.
for soname in $(printf '%s\n' "${!soname_package[@]}" | LC_ALL=C sort); do
  package=${soname_package[$soname]}
  root="$work_root/root-$package"
  mkdir -p -- "$root"
  canonical_library=$(readlink -f -- "${soname_file[$soname]}")
  libraries=()
  while IFS= read -r -d '' candidate; do
    [[ "$(readlink -f -- "$candidate")" == "$canonical_library" ]] && libraries+=("$candidate")
  done < <(find "$target_root/usr/lib" -maxdepth 1 \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
  [[ ${#libraries[@]} -gt 0 ]] || { echo "no files match target SONAME prefix: $soname" >&2; exit 76; }
  for library in "${libraries[@]}"; do
    claim_path "$library" "$package"
    copy_path "$library" "$root"
  done
  build_generated_package "$package" "TDVP K230 runtime library $soname" "$root"
done

copy_selector() {
  local selector=$1
  local package=$2
  local root=$3
  local source
  if [[ "$selector" == '@remaining-usr-lib' ]]; then
    while IFS= read -r -d '' source; do
      relative=${source#"$target_root"}
      case "$relative" in
        /usr/lib/ld-linux*|/usr/lib/libc.so*|/usr/lib/libdl.so*|/usr/lib/libm.so*|/usr/lib/libpthread.so*|/usr/lib/librt.so*|/usr/lib/libgcc_s.so*|/usr/lib/libstdc++.so*)
          continue
          ;;
      esac
      [[ -n "${claimed_paths[$relative]:-}" ]] && continue
      claim_path "$source" "$package"
      copy_path "$source" "$root"
    done < <(find "$target_root/usr/lib" -mindepth 2 \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
    return 0
  fi
  if [[ "$selector" == '@remaining-usr-libexec' ]]; then
    [[ -d "$target_root/usr/libexec" ]] || return 0
    while IFS= read -r -d '' source; do
      relative=${source#"$target_root"}
      [[ -n "${claimed_paths[$relative]:-}" ]] && continue
      claim_path "$source" "$package"
      copy_path "$source" "$root"
    done < <(find "$target_root/usr/libexec" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
    return 0
  fi
  if [[ "$selector" == '@remaining-usr-share' ]]; then
    while IFS= read -r -d '' source; do
      relative=${source#"$target_root"}
      [[ -n "${claimed_paths[$relative]:-}" ]] && continue
      claim_path "$source" "$package"
      copy_path "$source" "$root"
    done < <(find "$target_root/usr/share" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
    return 0
  fi
  shopt -s nullglob
  sources=("$target_root"$selector)
  shopt -u nullglob
  [[ ${#sources[@]} -gt 0 ]] || { echo "$package selector does not match target: $selector" >&2; exit 77; }
  for source in "${sources[@]}"; do
    if [[ -d "$source" && ! -L "$source" ]]; then
      while IFS= read -r -d '' nested; do
        claim_path "$nested" "$package"
      done < <(find "$source" \( -type f -o -type l \) -print0 | LC_ALL=C sort -z)
    else
      claim_path "$source" "$package"
    fi
    copy_path "$source" "$root"
  done
}

# Resource/module packages own data files and dlopen plugins.  They use the
# same automatic ELF resolver as library packages, so a TLS module or a GTK
# input method cannot bring an undeclared base-image dependency back in.
while IFS='|' read -r package description selectors; do
  package=${package%$'\r'}
  [[ -n "$package" && "$package" != \#* ]] || continue
  [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ && -n "$description" && -n "$selectors" ]] || {
    echo "invalid runtime data manifest record: $package" >&2
    exit 78
  }
  root="$work_root/root-$package"
  mkdir -p -- "$root"
  IFS=',' read -r -a selector_list <<< "$selectors"
  for selector in "${selector_list[@]}"; do
    selector=$(printf '%s' "$selector" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [[ -n "$selector" ]] && copy_selector "$selector" "$package" "$root"
  done
  if find "$root" -mindepth 1 -print -quit | grep -q .; then
    build_generated_package "$package" "$description" "$root"
  else
    rm -rf -- "$root"
  fi
done <"$data_manifest"

LC_ALL=C sort -u -o "$ownership_report" "$ownership_report"
printf 'runtime owner map: %s\n' "$owner_map"
printf 'runtime ownership report: %s\n' "$ownership_report"
echo "built ${#soname_file[@]} non-ABI SONAME packages from $target_root"
