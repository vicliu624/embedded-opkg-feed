#!/usr/bin/env bash
# Split the already-built Audacious executable and desktop integration from the
# core staging root. It never recompiles the core, FFmpeg, GTK3, ALSA or Pulse.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "audacious does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/audacious" && -d "$stage_root/usr/lib/audacious" ]] || { echo 'audacious requires core and plugin recipes to populate the release staging root first' >&2; exit 66; }

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/share"
install -m 0755 "$stage_root/usr/bin/audacious" "$payload_dir/usr/bin/audacious"
install -m 0755 "$package_dir/tdvp-audacious" "$payload_dir/usr/bin/tdvp-audacious"
install -Dm 0644 "$package_dir/tdvp-audacious.desktop" "$payload_dir/usr/share/applications/tdvp-audacious.desktop"
for source in "$stage_root/usr/share/icons/hicolor/48x48/apps/audacious.png" "$stage_root/usr/share/icons/hicolor/scalable/apps/audacious.svg" "$stage_root/usr/share/metainfo/audacious.metainfo.xml"; do
  [[ -f "$source" ]] || continue
  relative=${source#"$stage_root/usr/share/"}
  install -Dm 0644 "$source" "$payload_dir/usr/share/$relative"
done
for directory in "$stage_root/usr/share/locale" "$stage_root/usr/share/audacious"; do
  [[ -d "$directory" ]] || continue
  relative=${directory#"$stage_root/usr/share/"}
  cp -a -- "$directory" "$payload_dir/usr/share/$relative"
done
# Install this after copying the upstream data directory so the device-specific
# first-run layout cannot be overwritten by a future upstream source archive.
install -Dm 0644 "$package_dir/tdvp-k230-default.conf" "$payload_dir/usr/share/audacious/tdvp-k230-default.conf"
install -Dm 0644 "$stage_root/usr/share/doc/audacious/COPYING" "$payload_dir/usr/share/doc/audacious/COPYING" 2>/dev/null || true
echo "audacious payload ready: $payload_dir"
