#!/usr/bin/env bash
# Verify that the completed TDVP SDK already provides every development file
# Audacious needs. Feed batches consume this immutable sysroot directly and
# never rebuild an image-owned provider merely because it becomes a consumer
# dependency.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "Audacious foundation does not support platform: $2" >&2; exit 65; }

sdk_root=$4
[[ -d "$sdk_root" && ! -L "$sdk_root" ]] || { echo "Audacious foundation needs a regular SDK host directory: $sdk_root" >&2; exit 66; }
sdk_root=$(cd -- "$sdk_root" && pwd)
if [[ -f "$sdk_root/tdvp-sdk-manifest.json" ]]; then
  evidence_dir=${TDVP_AUDACIOUS_FOUNDATION_EVIDENCE_DIR:?foundation evidence directory is required}
  [[ ! -e "$evidence_dir" ]] || exit 70
  for dependency in glib-2.0 gio-2.0 gtk+-3.0 alsa libpulse libavcodec libavformat libavutil zlib; do
    "$sdk_root/bin/pkg-config" --exists "$dependency"
  done
  mkdir -p "$evidence_dir"
  { printf 'format\t1\nplatform\ttdvp-k230-r1\n';
    printf 'sdk_manifest_sha256\t%s\n' "$(sha256sum "$sdk_root/tdvp-sdk-manifest.json" | cut -d' ' -f1)";
  } >"$evidence_dir/tdvp-audacious-foundation.tsv"
  exit 0
fi
build_output=${TDVP_AUDACIOUS_BUILDROOT_OUTPUT:-$(cd -- "$sdk_root/.." && pwd)}
[[ "$sdk_root" == "$build_output/host" && -f "$build_output/.config" && -f "$build_output/Makefile" && -d "$build_output/target" ]] || {
  echo 'TDVP_AUDACIOUS_BUILDROOT_OUTPUT must be a completed matching Buildroot output' >&2
  exit 67
}
buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree" && -x "$buildroot_tree/utils/config" ]] || {
  echo 'could not resolve the locked Buildroot tree from the SDK output' >&2
  exit 68
}
actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == '2025.02.1' ]] || { echo "expected Buildroot 2025.02.1, got ${actual_buildroot_version:-unknown}" >&2; exit 69; }

base_download_dir=${TDVP_BUILDROOT_BASE_DOWNLOAD_DIR:-}
[[ -n "$base_download_dir" && -d "$base_download_dir" && ! -L "$base_download_dir" ]] || {
  echo 'Audacious foundation needs TDVP_BUILDROOT_BASE_DOWNLOAD_DIR from the reviewed SDK source cache' >&2
  exit 70
}
base_download_dir=$(cd -- "$base_download_dir" && pwd)
evidence_dir=${TDVP_AUDACIOUS_FOUNDATION_EVIDENCE_DIR:-}
[[ -n "$evidence_dir" && ! -e "$evidence_dir" && ! -L "$evidence_dir" ]] || {
  echo 'Audacious foundation needs a new TDVP_AUDACIOUS_FOUNDATION_EVIDENCE_DIR' >&2
  exit 70
}

config_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
providers=(libglib2 libgtk3 alsa-lib pulseaudio ffmpeg zlib)
sysroot="$sdk_root/riscv64-buildroot-linux-gnu/sysroot"
[[ -d "$sysroot" && ! -L "$sysroot" ]] || { echo "Audacious foundation needs the SDK sysroot: $sysroot" >&2; exit 71; }
required_development_files=(
  usr/lib/pkgconfig/glib-2.0.pc
  usr/lib/pkgconfig/gio-2.0.pc
  usr/lib/pkgconfig/gtk+-3.0.pc
  usr/lib/pkgconfig/alsa.pc
  usr/lib/pkgconfig/libpulse.pc
  usr/lib/pkgconfig/libavcodec.pc
  usr/lib/pkgconfig/libavformat.pc
  usr/lib/pkgconfig/libavutil.pc
  usr/lib/pkgconfig/zlib.pc
  usr/include/libavcodec/avcodec.h
  usr/include/libavformat/avformat.h
  usr/include/libavutil/avutil.h
)
for development_file in "${required_development_files[@]}"; do
  [[ -s "$sysroot/$development_file" ]] || {
    echo "Audacious foundation is missing SDK development input: $development_file" >&2
    exit 72
  }
done

mkdir -p -- "$evidence_dir"
{
  printf 'format\t1\n'
  printf 'platform\ttdvp-k230-r1\n'
  printf 'buildroot\t%s\n' "$actual_buildroot_version"
  printf 'config_sha256\t%s\n' "$config_hash"
  for provider in "${providers[@]}"; do
    printf 'provider\t%s\t%s\n' "$provider" 'SDK sysroot verified'
  done
  for development_file in "${required_development_files[@]}"; do
    printf 'development-file\t%s\n' "$development_file"
  done
} >"$evidence_dir/tdvp-audacious-foundation.tsv"

echo "Audacious foundation ready: $evidence_dir"
