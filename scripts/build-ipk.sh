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
  application|shared-library) ;;
  *)
    echo "invalid PACKAGE_KIND for $PACKAGE: $PACKAGE_KIND" >&2
    exit 71
    ;;
esac

if [[ -z "$PACKAGE_SECTION" ]]; then
  if [[ "$PACKAGE_KIND" == shared-library ]]; then
    PACKAGE_SECTION='libraries'
  else
    PACKAGE_SECTION='applications'
  fi
fi

payload_dir="$package_dir/root"
[[ -d "$payload_dir" ]] || { echo "missing payload root: $payload_dir" >&2; exit 72; }
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

assert_no_base_collision() {
  local base_root=${TDVP_FEED_BASE_ROOT:-}
  local payload_path relative base_path
  [[ -n "$base_root" ]] || return 0
  [[ -d "$base_root" ]] || {
    echo "TDVP_FEED_BASE_ROOT is not a target root: $base_root" >&2
    exit 75
  }
  while IFS= read -r -d '' payload_path; do
    relative=${payload_path#"$payload_dir"}
    base_path="$base_root$relative"
    if path_exists "$base_path"; then
      echo "$PACKAGE would replace a base-image path: $relative" >&2
      exit 76
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
          exit 78
        fi
        ;;
      /usr/share/doc/"$PACKAGE"/*|/usr/share/licenses/"$PACKAGE"/*)
        ;;
      *)
        echo "shared-library payload escapes its permitted paths: $relative" >&2
        exit 79
        ;;
    esac
  done < <(find "$payload_dir" -mindepth 1 \( -type f -o -type l \) -print0)

  local protected_pattern
  for protected_pattern in \
    'ld-linux*' 'libc.so*' 'libdl.so*' 'libm.so*' 'libpthread.so*' \
    'librt.so*' 'libgcc_s.so*' 'libstdc++.so*'; do
    if find "$payload_dir/usr/lib" -maxdepth 1 -name "$protected_pattern" -print -quit 2>/dev/null | grep -q .; then
      echo "shared-library payload attempts to replace protected runtime: $protected_pattern ($PACKAGE)" >&2
      exit 80
    fi
  done
}

if [[ "$PACKAGE_KIND" == shared-library ]]; then
  assert_shared_library_payload_paths
else
  assert_application_payload_paths
fi
assert_no_base_collision

work_dir=$(mktemp -d)
cleanup() { rm -rf -- "$work_dir"; }
trap cleanup EXIT
control_dir="$work_dir/control"
data_dir="$work_dir/data"
mkdir -p -- "$control_dir" "$data_dir"

depends="$ABI_PACKAGE (= $ABI_VERSION)"
if [[ -n "$PACKAGE_DEPENDS" ]]; then
  depends+=", $PACKAGE_DEPENDS"
fi

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
