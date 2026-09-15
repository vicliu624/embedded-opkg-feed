#!/usr/bin/env bash
# Build terminal Vim from the exact Buildroot source recipe, split its runtime
# data into this provider, and stage its executable only for the vim leaf.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "vim-runtime does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "$0")" && pwd)
sdk_root=$4
stage_root=${TDVP_FEED_STAGING_ROOT:?vim-runtime needs the release staging root}
configured_output=$(printenv TDVP_VIM_BUILDROOT_OUTPUT || true)
# shellcheck source=package.env
source "$package_dir/package.env"
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"

[[ -d "$sdk_root" && -d "$stage_root" ]] || {
  echo 'vim-runtime needs the release staging root and matching Buildroot SDK' >&2
  exit 66
}
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
grep -Fqx 'VIM_VERSION = 9.1.0145' "$tree/package/vim/vim.mk" || {
  echo 'locked Buildroot Vim version differs from the reviewed feed recipe' >&2
  exit 67
}
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$tree/package/vim/vim.hash" || {
  echo 'locked Buildroot Vim archive hash differs from the reviewed feed recipe' >&2
  exit 68
}

download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
install_root=$(mktemp -d)
payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix=/tmp/tdvp-command-payload.
cleanup() {
  local rc=$?
  rm -rf -- "$install_root"
  rm -rf -- "$download_dir"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tdvp_buildroot_install "$output" "$install_root" \
  --offline-download-dir "$download_dir" \
  --enable BR2_PACKAGE_VIM \
  --enable BR2_PACKAGE_VIM_RUNTIME \
  --target vim

[[ -x "$install_root/usr/bin/vim" && -d "$install_root/usr/share/vim" ]] || {
  echo 'Vim target install omitted its executable or runtime files' >&2
  exit 69
}
find "$install_root/usr/share/vim" -type f -name defaults.vim -print -quit | grep -q . || {
  echo 'Vim target install omitted defaults.vim' >&2
  exit 70
}
if [[ -L "$payload_link" ]]; then
  previous_payload=$(readlink -f -- "$payload_link" 2>/dev/null || true)
  if [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]]; then
    rm -rf -- "$previous_payload"
  fi
fi
rm -rf -- "$payload_link"
payload_dir=$(mktemp -d "$temporary_prefix"XXXXXX)
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$payload_link"
mkdir -p -- "$payload_dir/usr/share"
cp -a -- "$install_root/usr/share/vim" "$payload_dir/usr/share/vim"
install -Dm 0644 "$output/build/vim-9.1.0145/LICENSE" \
  "$payload_dir/usr/share/licenses/vim-runtime/LICENSE"
mkdir -p -- "$stage_root/usr"
cp -a -- "$install_root/usr/." "$stage_root/usr/"
payload_ready=1
echo "vim-runtime payload ready: $payload_dir"
