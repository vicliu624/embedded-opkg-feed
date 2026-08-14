#!/usr/bin/env bash
# Build one deterministic application .ipk for one declared platform.
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
platform_file="$repo_root/platforms/$platform_slug/platform.env"
package_dir=$(cd -- "$package_input" && pwd)

[[ -f "$platform_file" ]] || { echo "unknown platform: $platform_slug" >&2; exit 65; }
# shellcheck source=/dev/null
source "$platform_file"

[[ "$platform_slug" == "$PLATFORM_SLUG" ]] || {
  echo "platform manifest slug mismatch: $platform_slug" >&2
  exit 66
}
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

payload_dir="$package_dir/root"
[[ -d "$payload_dir" ]] || { echo "missing payload root: $payload_dir" >&2; exit 71; }
for tool in ar find gzip md5sum sha256sum tar; do
  command -v "$tool" >/dev/null || {
    echo "required build tool not found: $tool" >&2
    exit 72
  }
done

mkdir -p -- "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
ipk="$output_dir/${PACKAGE}_${VERSION}_${PACKAGE_ARCH}.ipk"
[[ ! -e "$ipk" ]] || { echo "refusing to overwrite immutable package: $ipk" >&2; exit 73; }

forbidden_paths=( './boot' './lib' './lib64' './usr/lib' './usr/lib/systemd' './usr/sbin' )
for prefix in "${forbidden_paths[@]}"; do
  if find "$payload_dir" -path "$payload_dir/${prefix#./}" -print -quit | grep -q .; then
    echo "payload writes a firmware-owned path ($prefix): $PACKAGE" >&2
    exit 74
  fi
done

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
Section: applications
Priority: optional
Description: $DESCRIPTION
EOF

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
