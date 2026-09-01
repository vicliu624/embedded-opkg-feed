#!/usr/bin/env bash
# Split the target-built Vim executable, terminal launcher, and system defaults
# from the runtime data staged by vim-runtime.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "vim does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stage_root=${TDVP_FEED_STAGING_ROOT:-}
[[ -n "$stage_root" && -x "$stage_root/usr/bin/vim" && -d "$stage_root/usr/share/vim" ]] || { echo 'vim requires vim-runtime to populate the release staging root first' >&2; exit 66; }

payload_dir="$package_dir/root"
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr"
cp -a -- "$stage_root/usr/bin" "$payload_dir/usr/bin"
install -Dm 0644 "$package_dir/vimrc" "$payload_dir/etc/vimrc"
install -Dm 0644 "$package_dir/tdvp-vim.desktop" "$payload_dir/usr/share/applications/tdvp-vim.desktop"
echo "vim payload ready: $payload_dir"
