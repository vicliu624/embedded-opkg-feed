#!/usr/bin/env bash
# Package the exact MPV binary from the locked Buildroot target.  Its shared
# libraries are supplied independently by the r4 runtime catalogue.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "tdvp-mpv does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target_root=${TDVP_FEED_BASE_ROOT:-}
[[ -n "$target_root" && -x "$target_root/usr/bin/mpv" ]] || {
  echo 'tdvp-mpv requires TDVP_FEED_BASE_ROOT with the locked target mpv binary' >&2
  exit 66
}

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
# The repository checkout is normally on a Windows drvfs mount, which reports
# every executable as mode 0777.  Materialise a POSIX staging root and expose
# it through a short-lived root/ symlink so the IPK records the target's real
# modes; build-all removes the symlink after packaging.
stage_parent=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_parent" && -d "$stage_parent" ]] || {
  echo 'tdvp-mpv requires TDVP_FEED_STAGING_ROOT from scripts/build-all.sh' >&2
  exit 67
}
stage_root="$stage_parent/.tdvp-mpv-payload"
rm -rf -- "$stage_root"
mkdir -p -- "$stage_root/usr/bin" "$stage_root/usr/share/applications" "$stage_root/usr/share/metainfo"
install -m 0755 "$target_root/usr/bin/mpv" "$stage_root/usr/bin/mpv"
[[ -f "$target_root/usr/share/applications/mpv.desktop" ]] && \
  install -m 0644 "$target_root/usr/share/applications/mpv.desktop" "$stage_root/usr/share/applications/mpv.desktop"
[[ -f "$target_root/usr/share/metainfo/mpv.metainfo.xml" ]] && \
  install -m 0644 "$target_root/usr/share/metainfo/mpv.metainfo.xml" "$stage_root/usr/share/metainfo/mpv.metainfo.xml"
ln -s -- "$stage_root" "$payload_dir"
echo "tdvp-mpv payload ready: $payload_dir"
