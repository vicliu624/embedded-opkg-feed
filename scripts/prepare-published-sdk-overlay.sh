#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# == 2 ]] || { echo 'usage: prepare-published-sdk-overlay.sh <sdk> <new-overlay>' >&2; exit 64; }
sdk=$(cd "$1" && pwd)
overlay=$2
[[ -f "$sdk/tdvp-sdk-manifest.json" && ! -e "$overlay" ]] || exit 65
mkdir -p "$overlay/include"
cp -a "$sdk/sysroot/usr/include/." "$overlay/include/"
if [[ -d "$overlay/include/freetype2" ]]; then
  cp -a "$overlay/include/freetype2/." "$overlay/include/"
fi
ln -s "$sdk/sysroot/usr/lib" "$overlay/lib"
ln -s "$sdk/sysroot/usr/share" "$overlay/share"
source "$(dirname "${BASH_SOURCE[0]}")/tdvp-k230-sdk.sh"
TDVP_K230_WAYLAND_SDK_OVERLAY=$overlay
tdvp_require_wayland_sdk_overlay
