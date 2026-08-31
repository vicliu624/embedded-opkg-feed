#!/usr/bin/env bash
# Build the terminal-only Vim package through the exact locked Buildroot tree,
# then split its reusable runtime data from the executable leaf package.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "vim-runtime does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
sdk_root=$4
source "$package_dir/package.env"

[[ -d "$sdk_root" && -d "${TDVP_FEED_STAGING_ROOT:-}" ]] || { echo 'vim-runtime needs the release staging root and matching Buildroot SDK' >&2; exit 66; }
sdk_root=$(cd -- "$sdk_root" && pwd)
build_output=${TDVP_VIM_BUILDROOT_OUTPUT:-$(cd -- "$sdk_root/.." && pwd)}
[[ "$sdk_root" == "$build_output/host" && -f "$build_output/.config" && -f "$build_output/Makefile" && -d "$build_output/target" ]] || { echo 'TDVP_VIM_BUILDROOT_OUTPUT must be a completed matching Buildroot output' >&2; exit 67; }
buildroot_tree=$(awk '$1 == "MAKEARGS" && ($2 == ":=" || $2 == "+=") && $3 == "-C" { print $4; exit }' "$build_output/Makefile")
[[ -n "$buildroot_tree" && -d "$buildroot_tree/package/vim" && -x "$buildroot_tree/utils/config" ]] || { echo 'could not resolve the locked Buildroot Vim package from the SDK output' >&2; exit 68; }
actual_buildroot_version=$(awk '$1 == "export" && $2 == "BR2_VERSION" && $3 == ":=" { print $4; exit }' "$buildroot_tree/Makefile")
[[ "$actual_buildroot_version" == '2025.02.1' ]] || { echo "expected Buildroot 2025.02.1, got ${actual_buildroot_version:-unknown}" >&2; exit 69; }
grep -Fqx 'VIM_VERSION = 9.1.0145' "$buildroot_tree/package/vim/vim.mk" || { echo 'locked Buildroot Vim version differs from the reviewed feed recipe' >&2; exit 70; }
grep -Fqx "sha256  $SOURCE_ARCHIVE_SHA256  $SOURCE_ARCHIVE" "$buildroot_tree/package/vim/vim.hash" || { echo 'locked Buildroot Vim archive hash differs from the reviewed feed recipe' >&2; exit 71; }

config_backup=$(mktemp "$build_output/.config.tdvp-vim.XXXXXX")
install_root=$(mktemp -d)
payload_dir="$package_dir/root"
config_hash=$(sha256sum "$build_output/.config" | awk '{print $1}')
config_saved=0

cleanup() {
  local rc=$?
  set +e
  if [[ "$config_saved" -eq 1 ]]; then
    cp -- "$config_backup" "$build_output/.config"
    # Regenerate derived Buildroot configuration too: the Vim package is a
    # feed build input, never a latent setting for the next firmware image.
    env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" olddefconfig || rc=98
    [[ "$(sha256sum "$build_output/.config" | awk '{print $1}')" == "$config_hash" ]] || rc=99
  fi
  rm -f -- "$config_backup"
  rm -rf -- "$install_root"
  exit "$rc"
}
trap cleanup EXIT

cp -- "$build_output/.config" "$config_backup"; config_saved=1
"$buildroot_tree/utils/config" --file "$build_output/.config" --enable BR2_PACKAGE_VIM --enable BR2_PACKAGE_VIM_RUNTIME
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" olddefconfig
grep -qx 'BR2_PACKAGE_VIM=y' "$build_output/.config"
grep -qx 'BR2_PACKAGE_VIM_RUNTIME=y' "$build_output/.config"
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" vim-dirclean
env -i HOME="${HOME:-/tmp}" USER="${USER:-tdvp}" LOGNAME="${LOGNAME:-tdvp}" PATH="$sdk_root/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" make -C "$build_output" TARGET_DIR="$install_root" vim-install-target

[[ -x "$install_root/usr/bin/vim" ]] || { echo 'Vim target install omitted /usr/bin/vim' >&2; exit 72; }
find "$install_root/usr/share/vim" -type f -name 'defaults.vim' -print -quit | grep -q . || { echo 'Vim target install omitted its runtime files' >&2; exit 73; }
rm -rf -- "$payload_dir"
mkdir -p -- "$payload_dir/usr/share"
cp -a -- "$install_root/usr/share/vim" "$payload_dir/usr/share/vim"
install -Dm 0644 "$build_output/build/vim-9.1.0145/LICENSE" "$payload_dir/usr/share/licenses/vim-runtime/LICENSE"
mkdir -p -- "$TDVP_FEED_STAGING_ROOT/usr"
cp -a -- "$install_root/usr/." "$TDVP_FEED_STAGING_ROOT/usr/"
echo "vim-runtime payload ready: $payload_dir"
