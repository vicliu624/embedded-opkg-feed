#!/usr/bin/env bash
# Materialise Audacious' upstream Buildroot providers before any Audacious
# recipe is compiled. The resulting package stamps and staging sysroot are a
# private CI build-state input; runtime ownership remains in the target-derived
# feed catalogue.
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
# The SDK-base cache intentionally keeps the host, target and Buildroot state
# while excluding generated image files. Some K230 package install hooks still
# emit a transient Debian archive under images/deb; recreate only that empty
# output directory before the provider target-install phase.
mkdir -p -- "$build_output/images/deb"
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" \
  PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  BR2_DL_DIR="$base_download_dir" BR2_PRIMARY_SITE="file://$base_download_dir" BR2_PRIMARY_SITE_ONLY=y \
  make -C "$build_output" "${providers[@]}"
[[ "$(sha256sum "$build_output/.config" | awk '{print $1}')" == "$config_hash" ]] || {
  echo 'Audacious foundation changed the caller-owned Buildroot configuration' >&2
  exit 71
}

mkdir -p -- "$evidence_dir"
{
  printf 'format\t1\n'
  printf 'platform\ttdvp-k230-r1\n'
  printf 'buildroot\t%s\n' "$actual_buildroot_version"
  printf 'config_sha256\t%s\n' "$config_hash"
  for provider in "${providers[@]}"; do
    stamp=$(find "$build_output/build" -maxdepth 2 -type f -path "*/${provider}-*/.stamp_staging_installed" -print -quit)
    [[ -n "$stamp" ]] || { echo "Audacious foundation omitted provider staging stamp: $provider" >&2; exit 72; }
    printf 'provider\t%s\t%s\n' "$provider" "${stamp#"$build_output/"}"
  done
} >"$evidence_dir/tdvp-audacious-foundation.tsv"

echo "Audacious foundation ready: $evidence_dir"
