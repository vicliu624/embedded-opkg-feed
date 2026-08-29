#!/usr/bin/env bash
# Build an ABI-bound NetSurf GTK3 payload from the same completed Buildroot
# profile that supplies its runtime libraries.  Nothing from this recipe is
# installed into that firmware target tree.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <buildroot-output/host>" >&2
  exit 64
fi

platform_slug=$2
sdk_root=$4
package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=/dev/null
source "$package_dir/package.env"

: "${PACKAGE:?package.env must set PACKAGE}"
: "${VERSION:?package.env must set VERSION}"
: "${SOURCE_ARCHIVE:?package.env must set SOURCE_ARCHIVE}"
: "${SOURCE_ARCHIVE_SHA256:?package.env must set SOURCE_ARCHIVE_SHA256}"
: "${BUILDROOT_VERSION:?package.env must set BUILDROOT_VERSION}"

[[ "$platform_slug" == 'tdvp-k230-r1' ]] || {
  echo "tdvp-netsurf does not support platform: $platform_slug" >&2
  exit 65
}
[[ "$SOURCE_ARCHIVE_SHA256" =~ ^[0-9a-f]{64}$ ]] || {
  echo 'SOURCE_ARCHIVE_SHA256 must be a lowercase SHA-256 digest' >&2
  exit 66
}

[[ -n "$sdk_root" && -d "$sdk_root" ]] || {
  echo 'tdvp-netsurf requires --sdk-root <matching-buildroot-output/host>' >&2
  exit 67
}

sdk_root=$(cd -- "$sdk_root" && pwd)
build_output=${TDVP_NETSURF_BUILDROOT_OUTPUT:-}
if [[ -z "$build_output" ]]; then
  build_output=$(cd -- "$sdk_root/.." && pwd)
fi
[[ -d "$build_output" ]] || {
  echo 'TDVP_NETSURF_BUILDROOT_OUTPUT must name a completed TDVP Buildroot profile output' >&2
  exit 68
}
build_output=$(cd -- "$build_output" && pwd)
[[ "$sdk_root" == "$build_output/host" ]] || {
  echo 'TDVP_SDK_ROOT must be exactly TDVP_NETSURF_BUILDROOT_OUTPUT/host' >&2
  exit 69
}
[[ -f "$build_output/.config" && -f "$build_output/Makefile" &&
   -d "$build_output/host" && -d "$build_output/target" ]] || {
  echo "not a completed Buildroot profile output: $build_output" >&2
  exit 70
}

buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' \
  "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree" &&
   -x "$buildroot_tree/utils/config" &&
   -f "$buildroot_tree/package/netsurf/netsurf.mk" &&
   -f "$buildroot_tree/package/netsurf/netsurf.hash" ]] || {
  echo 'could not resolve a Buildroot tree with the NetSurf package from the profile output' >&2
  exit 71
}

actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' \
  "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == "$BUILDROOT_VERSION" ]] || {
  echo "expected Buildroot $BUILDROOT_VERSION, got ${actual_buildroot_version:-unknown}" >&2
  exit 72
}

declared_hash=$(awk -v source="$SOURCE_ARCHIVE" \
  '$1 == "sha256" && $3 == source { print $2; exit }' \
  "$buildroot_tree/package/netsurf/netsurf.hash")
[[ "$declared_hash" == "$SOURCE_ARCHIVE_SHA256" ]] || {
  echo 'Buildroot NetSurf source checksum does not match this reviewed recipe' >&2
  exit 73
}

patch_source="$package_dir/patches/0001-gtk3-use-png-for-the-preprocessed-icon.patch"
desktop_source="$package_dir/tdvp-netsurf.desktop"
[[ -f "$patch_source" && -f "$desktop_source" ]] || {
  echo 'tdvp-netsurf recipe assets are incomplete' >&2
  exit 74
}

patch_target="$buildroot_tree/package/netsurf/999-tdvp-netsurf-png-resource.patch"
[[ ! -e "$patch_target" ]] || {
  echo "refusing to replace an existing Buildroot patch: $patch_target" >&2
  exit 75
}

for tool in awk cp find install make mktemp rm sha256sum sed; do
  command -v "$tool" >/dev/null || {
    echo "required build tool is missing: $tool" >&2
    exit 76
  }
done

config_backup=$(mktemp "$build_output/.config.tdvp-netsurf.XXXXXX")
install_root=$(mktemp -d)
payload_dir="$package_dir/root"
config_sha256=$(sha256sum "$build_output/.config" | awk '{print $1}')
config_saved=0
patch_staged=0

cleanup() {
  local rc=$?
  set +e
  if [[ "$config_saved" -eq 1 ]]; then
    cp -- "$config_backup" "$build_output/.config"
    restored_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
    if [[ "$restored_hash" != "$config_sha256" ]]; then
      echo 'failed to restore the original Buildroot configuration' >&2
      rc=99
    fi
  fi
  rm -f -- "$config_backup"
  if [[ "$patch_staged" -eq 1 ]]; then
    rm -f -- "$patch_target"
  fi
  rm -rf -- "$install_root"
  exit "$rc"
}
trap cleanup EXIT

cp -- "$build_output/.config" "$config_backup"
config_saved=1
install -m 0644 "$patch_source" "$patch_target"
patch_staged=1

# This mutates only the profile configuration for the duration of this build.
# The trap above restores its byte-for-byte SHA-256 before the hook returns.
"$buildroot_tree/utils/config" --file "$build_output/.config" \
  --enable BR2_PACKAGE_NETSURF \
  --enable BR2_PACKAGE_NETSURF_GTK3
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
  PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  make -C "$build_output" olddefconfig
grep -qx 'BR2_PACKAGE_NETSURF=y' "$build_output/.config"
grep -qx 'BR2_PACKAGE_NETSURF_GTK3=y' "$build_output/.config"

# Reapply the versioned feed patch to a clean NetSurf package build directory.
# This is limited to build/netsurf-*; it never removes the firmware target,
# image artifacts, or a user data partition.
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
  PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  make -C "$build_output" netsurf-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
  PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  make -C "$build_output" TARGET_DIR="$install_root" netsurf-install-target

browser_binary="$install_root/usr/bin/netsurf-gtk3"
strip_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-strip"
readelf_tool="$sdk_root/bin/riscv64-unknown-linux-gnu-readelf"
[[ -f "$browser_binary" && -x "$strip_tool" && -x "$readelf_tool" ]] || {
  echo 'NetSurf target install did not yield the expected K230 GTK3 browser binary' >&2
  exit 77
}
"$strip_tool" --strip-unneeded "$browser_binary"
if "$readelf_tool" -d "$browser_binary" | grep -Eq '\((RPATH|RUNPATH)\)'; then
  echo 'NetSurf binary carries an RPATH/RUNPATH and cannot be released' >&2
  exit 78
fi

# The matching target is used only as a build-time ABI reference.  The r3
# closure checker later resolves every non-ABI SONAME from the generated feed
# owner map and requires an exact Depends; this loop merely rejects a browser
# built against an unknown platform library before it is packaged.
while IFS= read -r soname; do
  [[ -n "$soname" ]] || continue
  find "$build_output/target/lib" "$build_output/target/usr/lib" \
    -maxdepth 2 \( -type f -o -type l \) -name "$soname" -print -quit | grep -q . || {
      echo "NetSurf direct runtime dependency is absent from the matching ABI reference target: $soname" >&2
      exit 79
    }
done < <("$readelf_tool" -d "$browser_binary" \
  | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')

# root/ is build-owned recipe output.  It is scoped to this package and is
# ignored by Git; generated payloads are never checked in or promoted alone.
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir"
cp -a -- "$install_root/." "$payload_dir/"
install -Dm 0644 "$desktop_source" \
  "$payload_dir/usr/share/applications/tdvp-netsurf.desktop"
install -Dm 0644 "$install_root/usr/share/netsurf/netsurf.png" \
  "$payload_dir/usr/share/icons/hicolor/128x128/apps/tdvp-netsurf.png"
install -Dm 0644 "$build_output/build/netsurf-3.10/netsurf/COPYING" \
  "$payload_dir/usr/share/doc/tdvp-netsurf/COPYING"

echo "tdvp-netsurf payload ready: $payload_dir"
