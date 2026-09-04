#!/usr/bin/env bash
# Build one deterministic application or audited shared-runtime .ipk for one
# declared platform.  A normal application cannot write a firmware library
# directory.  An explicit shared-library recipe can, but only with a narrow
# runtime payload and never over an immutable base-image path.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' ]]; then
  echo "usage: $0 --platform <platform-slug> <package-directory> <output-directory>" >&2
  exit 64
fi

platform_slug=$2
package_input=$3
output_dir=$4
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir=$(cd -- "$package_input" && pwd)

# shellcheck source=feed-platform.sh
source "$script_dir/feed-platform.sh"
# shellcheck source=../support/elf-runtime-policy.sh
source "$repo_root/support/elf-runtime-policy.sh"
tdvp_load_platform "$repo_root" "$platform_slug"

[[ -f "$package_dir/package.env" ]] || {
  echo "missing package.env: $package_dir" >&2
  exit 67
}

# package.env is versioned, reviewed repository input.
# shellcheck source=/dev/null
source "$package_dir/package.env"

: "${PACKAGE:?package.env must set PACKAGE}"
: "${VERSION:?package.env must set VERSION}"
: "${DESCRIPTION:?package.env must set DESCRIPTION}"
: "${MAINTAINER:?package.env must set MAINTAINER}"
: "${SUPPORTED_PLATFORMS:?package.env must set SUPPORTED_PLATFORMS}"
: "${PACKAGE_ARCH:=$ARCH}"
: "${PACKAGE_DEPENDS:=}"
: "${PACKAGE_BUILD_DEPENDS:=}"
: "${PACKAGE_KIND:=application}"
: "${PACKAGE_RELEASES:=r1}"
: "${PACKAGE_PROVIDES:=}"
: "${PACKAGE_SECTION:=}"
: "${PACKAGE_BASE_OVERLAY:=deny}"
: "${PACKAGE_AUTO_RUNTIME_DEPENDS:=0}"

if [[ ! "$PACKAGE" =~ ^[a-z0-9][a-z0-9+.-]*$ ]]; then
  echo "invalid lowercase opkg package name: $PACKAGE" >&2
  exit 68
fi
if [[ "$PACKAGE_ARCH" != "$ARCH" ]]; then
  echo "package architecture must be $ARCH, got $PACKAGE_ARCH" >&2
  exit 69
fi
if [[ " $SUPPORTED_PLATFORMS " != *" $PLATFORM_SLUG "* ]]; then
  echo "$PACKAGE does not declare support for $PLATFORM_SLUG" >&2
  exit 70
fi
case "$PACKAGE_KIND" in
  application|shared-library|runtime) ;;
  *)
    echo "invalid PACKAGE_KIND for $PACKAGE: $PACKAGE_KIND" >&2
    exit 71
    ;;
esac

if [[ -z "$PACKAGE_SECTION" ]]; then
  if [[ "$PACKAGE_KIND" == shared-library || "$PACKAGE_KIND" == runtime ]]; then
    PACKAGE_SECTION='libraries'
  else
    PACKAGE_SECTION='applications'
  fi
fi

payload_dir="$package_dir/root"
[[ -d "$payload_dir" ]] || { echo "missing payload root: $payload_dir" >&2; exit 72; }
# A build hook may materialise its payload on a POSIX staging filesystem and
# expose it as root/ through a symlink (the repository itself can live on a
# Windows drvfs mount, which does not preserve the target executable modes).
# Resolve that directory before every audit below: find(1) otherwise treats
# root/ as a terminal symlink, silently skipping both base-overlay checks and
# ELF-derived runtime dependencies.
payload_dir=$(cd -- "$payload_dir" && pwd -P)
for tool in ar find gzip md5sum sha256sum tar; do
  command -v "$tool" >/dev/null || {
    echo "required build tool not found: $tool" >&2
    exit 73
  }
done

mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
ipk="$output_dir/${PACKAGE}_${VERSION}_${PACKAGE_ARCH}.ipk"
[[ ! -e "$ipk" ]] || { echo "refusing to overwrite immutable package: $ipk" >&2; exit 74; }

path_exists() {
  [[ -e "$1" || -L "$1" ]]
}

assert_base_overlay_policy() {
  local base_root=${TDVP_FEED_BASE_ROOT:-}
  local payload_path relative base_path payload_mode base_mode
  [[ -n "$base_root" ]] || return 0
  [[ -d "$base_root" ]] || {
    echo "TDVP_FEED_BASE_ROOT is not a target root: $base_root" >&2
    exit 75
  }
  case "$PACKAGE_BASE_OVERLAY" in
    deny|identical) ;;
    *)
      echo "invalid PACKAGE_BASE_OVERLAY for $PACKAGE: $PACKAGE_BASE_OVERLAY" >&2
      exit 76
      ;;
  esac
  while IFS= read -r -d '' payload_path; do
    relative=${payload_path#"$payload_dir"}
    base_path="$base_root$relative"
    if path_exists "$base_path"; then
      if [[ "$PACKAGE_BASE_OVERLAY" != identical ]]; then
        echo "$PACKAGE would replace a base-image path: $relative" >&2
        exit 77
      fi
      if [[ -L "$payload_path" && -L "$base_path" ]]; then
        [[ "$(readlink -- "$payload_path")" == "$(readlink -- "$base_path")" ]] || {
          echo "$PACKAGE base-overlay symlink differs: $relative" >&2
          exit 78
        }
      elif [[ -f "$payload_path" && -f "$base_path" ]]; then
        payload_mode=$(stat -c '%a' -- "$payload_path")
        base_mode=$(stat -c '%a' -- "$base_path")
        [[ "$payload_mode" == "$base_mode" ]] && cmp -s -- "$payload_path" "$base_path" || {
          echo "$PACKAGE base-overlay file differs: $relative" >&2
          exit 79
        }
      else
        echo "$PACKAGE base-overlay file type differs: $relative" >&2
        exit 80
      fi
    fi
  done < <(find "$payload_dir" -mindepth 1 \( -type f -o -type l \) -print0)
}

assert_application_payload_paths() {
  local prefix
  for prefix in /boot /lib /lib64 /usr/lib /usr/lib/systemd /usr/sbin; do
    if path_exists "$payload_dir$prefix"; then
      echo "application payload writes a firmware-owned path ($prefix): $PACKAGE" >&2
      exit 77
    fi
  done
}

assert_shared_library_payload_paths() {
  local payload_path relative basename
  while IFS= read -r -d '' payload_path; do
    relative=${payload_path#"$payload_dir"}
    case "$relative" in
      /usr/lib/*)
        basename=${payload_path##*/}
        if [[ ! "$basename" =~ ^lib[A-Za-z0-9_+.-]+\.so(\.[A-Za-z0-9_+.-]+)*$ ]]; then
          echo "shared-library payload contains a non-runtime file: $relative" >&2
          exit 81
        fi
        ;;
      /usr/share/doc/"$PACKAGE"/*|/usr/share/licenses/"$PACKAGE"/*)
        ;;
      *)
        echo "shared-library payload escapes its permitted paths: $relative" >&2
        exit 82
        ;;
    esac
  done < <(find "$payload_dir" -mindepth 1 \( -type f -o -type l \) -print0)

  local protected_pattern
  for protected_pattern in \
    'ld-linux*' 'libc.so*' 'libdl.so*' 'libm.so*' 'libpthread.so*' \
    'librt.so*' 'libutil.so*' 'libresolv.so*' 'libgcc_s.so*' 'libstdc++.so*'; do
    if find "$payload_dir/usr/lib" -maxdepth 1 -name "$protected_pattern" -print -quit 2>/dev/null | grep -q .; then
      echo "shared-library payload attempts to replace protected runtime: $protected_pattern ($PACKAGE)" >&2
      exit 83
    fi
  done
}

assert_runtime_payload_paths() {
  local payload_path relative
  while IFS= read -r -d '' payload_path; do
    relative=${payload_path#"$payload_dir"}
    case "$relative" in
      /usr/lib/*|/usr/libexec/*|/usr/share/*|/etc/*)
        ;;
      *)
        echo "runtime payload escapes its permitted paths: $relative" >&2
        exit 84
        ;;
    esac
  done < <(find "$payload_dir" -mindepth 1 \( -type f -o -type l \) -print0)

  local protected_pattern
  for protected_pattern in \
    'ld-linux*' 'libc.so*' 'libdl.so*' 'libm.so*' 'libpthread.so*' \
    'librt.so*' 'libutil.so*' 'libresolv.so*' 'libgcc_s.so*' 'libstdc++.so*'; do
    if find "$payload_dir/usr/lib" -maxdepth 1 -name "$protected_pattern" -print -quit 2>/dev/null | grep -q .; then
      echo "runtime payload attempts to replace protected ABI runtime: $protected_pattern ($PACKAGE)" >&2
      exit 85
    fi
  done
}

assert_elf_runtime_search_path_policy() {
  local readelf_tool=$1 elf=$2 base_root=${TDVP_FEED_BASE_ROOT:-}
  local relative base_elf payload_mode base_mode
  # Source-built payloads and target objects without a dynamic search path use
  # the narrow shared policy.  A non-empty target path may survive only as a
  # byte-identical ownership transfer from the locked base image; this matches
  # the release-level closure audit and cannot be used to introduce an SDK or
  # $ORIGIN path in a newly built library.
  if ! "$readelf_tool" -dW "$elf" 2>/dev/null | grep -Eq '\((RPATH|RUNPATH)\)'; then
    return 0
  fi
  if [[ "$PACKAGE_BASE_OVERLAY" == identical && -n "$base_root" ]]; then
    relative=${elf#"$payload_dir"}
    base_elf="$base_root$relative"
    if [[ -f "$base_elf" ]] && cmp -s -- "$elf" "$base_elf"; then
      payload_mode=$(stat -c '%a' -- "$elf")
      base_mode=$(stat -c '%a' -- "$base_elf")
      if [[ "$payload_mode" == "$base_mode" ]]; then
        echo "$PACKAGE retains a byte-identical target RPATH/RUNPATH: $relative" >&2
        return 0
      fi
    fi
  fi
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$elf"
}

case "$PACKAGE_KIND" in
  shared-library) assert_shared_library_payload_paths ;;
  runtime) assert_runtime_payload_paths ;;
  application) assert_application_payload_paths ;;
esac
assert_base_overlay_policy

work_dir=$(mktemp -d)
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT
control_dir="$work_dir/control"
data_dir="$work_dir/data"
mkdir -p -- "$control_dir" "$data_dir"

declare -A declared_dependencies=()
declare -a dependency_records=()

append_dependency() {
  local record=$1
  local name
  name=$(printf '%s' "$record" | sed -E 's/^[[:space:]]*([^[:space:]<(=]+).*/\1/')
  [[ -n "$name" ]] || { echo "invalid dependency record for $PACKAGE: $record" >&2; exit 86; }
  if [[ -z "${declared_dependencies[$name]:-}" ]]; then
    declared_dependencies[$name]=1
    dependency_records+=("$record")
  fi
}

append_dependency "$ABI_PACKAGE (= $ABI_VERSION)"
if [[ -n "$PACKAGE_DEPENDS" ]]; then
  IFS=',' read -r -a configured_dependencies <<< "$PACKAGE_DEPENDS"
  for configured_dependency in "${configured_dependencies[@]}"; do
    configured_dependency=$(printf '%s' "$configured_dependency" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    [[ -n "$configured_dependency" ]] && append_dependency "$configured_dependency"
  done
fi

if [[ "$PACKAGE_AUTO_RUNTIME_DEPENDS" == 1 ]]; then
  runtime_owner_map=${TDVP_RUNTIME_OWNER_MAP:-}
  readelf_tool=${TDVP_READELF:-}
  [[ -s "$runtime_owner_map" ]] || {
    echo "$PACKAGE enables PACKAGE_AUTO_RUNTIME_DEPENDS but TDVP_RUNTIME_OWNER_MAP is missing" >&2
    exit 87
  }
  [[ -n "$readelf_tool" && -x "$readelf_tool" ]] || {
    echo "$PACKAGE enables PACKAGE_AUTO_RUNTIME_DEPENDS but TDVP_READELF is missing" >&2
    exit 88
  }
  while IFS= read -r elf; do
    assert_elf_runtime_search_path_policy "$readelf_tool" "$elf" || exit $?
  done < <(find "$payload_dir" -type f \( -perm -u+x -o -name '*.so*' \) -print | LC_ALL=C sort)
  declare -A payload_sonames=()
  while IFS= read -r elf; do
    while IFS= read -r provided_soname; do
      [[ -n "$provided_soname" ]] && payload_sonames[$provided_soname]=1
    done < <("$readelf_tool" -d "$elf" 2>/dev/null | sed -n 's/.*SONAME.*\[\(.*\)\]/\1/p')
  done < <(find "$payload_dir" -type f \( -perm -u+x -o -name '*.so*' \) -print | LC_ALL=C sort)
  while IFS= read -r elf; do
    while IFS= read -r soname; do
      [[ -n "$soname" ]] || continue
      owner_record=$(awk -F'|' -v soname="$soname" '
        $1 == soname {
          version = $3
          sub(/\r$/, "", version)
          print $2 "|" version
          exit
        }
      ' "$runtime_owner_map")
      if [[ -z "$owner_record" && -n "${payload_sonames[$soname]:-}" ]]; then
        # A dlopen-module package can contain a small family of private
        # helper libraries below /usr/lib.  Its provider is this same IPK;
        # the global map intentionally only names independently reusable
        # top-level SONAME packages.
        continue
      fi
      if [[ -z "$owner_record" ]]; then
        case "$soname" in
          ld-linux-riscv64-lp64d.so.1|libc.so.6|libdl.so.2|libm.so.6|libpthread.so.0|librt.so.1|libutil.so.1|libresolv.so.2|libgcc_s.so.1|libstdc++.so.6)
            continue
            ;;
          *)
            echo "$PACKAGE needs $soname, but the runtime owner map has no provider" >&2
            exit 89
            ;;
        esac
      fi
      owner=${owner_record%%|*}
      owner_version=${owner_record#*|}
      [[ "$owner" == "$PACKAGE" ]] || append_dependency "$owner (= $owner_version)"
    done < <("$readelf_tool" -d "$elf" 2>/dev/null | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
  done < <(find "$payload_dir" -type f \( -perm -u+x -o -name '*.so*' \) -print | LC_ALL=C sort)
elif [[ "$PACKAGE_AUTO_RUNTIME_DEPENDS" != 0 ]]; then
  echo "PACKAGE_AUTO_RUNTIME_DEPENDS must be 0 or 1 for $PACKAGE" >&2
  exit 90
fi

depends=$(IFS=', '; printf '%s' "${dependency_records[*]}")

cat >"$control_dir/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Architecture: $PACKAGE_ARCH
Depends: $depends
Maintainer: $MAINTAINER
Section: $PACKAGE_SECTION
Priority: optional
Description: $DESCRIPTION
EOF
if [[ -n "$PACKAGE_PROVIDES" ]]; then
  printf 'Provides: %s\n' "$PACKAGE_PROVIDES" >>"$control_dir/control"
fi

# Copy while preserving executable mode and symlinks. Payloads and build hooks
# must be reviewed; a PR cannot promote generated release artifacts.
cp -a -- "$payload_dir/." "$data_dir/"
(
  cd -- "$control_dir"
  tar --format=gnu --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -cf - ./control | gzip -n -9 >"$work_dir/control.tar.gz"
)
(
  cd -- "$data_dir"
  tar --format=gnu --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -cf - . | gzip -n -9 >"$work_dir/data.tar.gz"
)
printf '2.0\n' >"$work_dir/debian-binary"
(
  cd -- "$work_dir"
  ar rD "$ipk" debian-binary control.tar.gz data.tar.gz
)
echo "built $ipk"
