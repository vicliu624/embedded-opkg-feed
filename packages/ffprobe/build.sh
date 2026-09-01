#!/usr/bin/env bash
# Build and package only the ffprobe frontend from TDVP's locked Buildroot
# FFmpeg recipe.  The temporary Buildroot config is restored byte-for-byte by
# tdvp_buildroot_install, so a feed build cannot alter the next firmware image.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
# shellcheck source=/dev/null
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"

output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "${TDVP_FFPROBE_BUILDROOT_OUTPUT:-}")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'FFMPEG_VERSION = 4.4.4' "$tree/package/ffmpeg/ffmpeg.mk" || {
  echo 'locked Buildroot FFmpeg source differs from ffprobe 4.4.4-1' >&2
  exit 65
}
grep -Fqx 'sha256  e80b380d595c809060f66f96a5d849511ef4a76a26b76eacf5778b94c3570309  ffmpeg-4.4.4.tar.xz' \
  "$tree/package/ffmpeg/ffmpeg.hash" || {
  echo 'locked Buildroot FFmpeg archive checksum differs from ffprobe 4.4.4-1' >&2
  exit 66
}

install_root=$(mktemp -d)
cleanup() { rm -rf -- "$install_root"; }
trap cleanup EXIT
tdvp_buildroot_install "$output" "$install_root" \
  --enable BR2_PACKAGE_FFMPEG \
  --enable BR2_PACKAGE_FFMPEG_FFPROBE \
  --target ffmpeg
[[ -x "$install_root/usr/bin/ffprobe" ]] || {
  echo 'FFmpeg target install omitted /usr/bin/ffprobe' >&2
  exit 67
}

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/bin"
install -Dm 0755 "$install_root/usr/bin/ffprobe" "$payload_dir/usr/bin/ffprobe"
echo "ffprobe payload ready: $payload_dir"
