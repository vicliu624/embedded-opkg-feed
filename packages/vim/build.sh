#!/usr/bin/env bash
# Split the target-built Vim executable and TDVP defaults from vim-runtime.
set -Eeuo pipefail
IFS=$'\n\t'

if [[ $# -ne 4 || "$1" != '--platform' || "$3" != '--sdk-root' ]]; then
  echo "usage: $0 --platform tdvp-k230-r1 --sdk-root <matching-buildroot-output/host>" >&2
  exit 64
fi
[[ "$2" == tdvp-k230-r1 ]] || { echo "vim does not support platform: $2" >&2; exit 65; }

package_dir=$(cd -- "$(dirname -- "$0")" && pwd)
sdk_root=$4
stage_root=${TDVP_FEED_STAGING_ROOT:?vim requires vim-runtime to populate the release staging root first}
configured_output=$(printenv TDVP_VIM_BUILDROOT_OUTPUT || true)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

[[ -x "$stage_root/usr/bin/vim" && -d "$stage_root/usr/share/vim" ]] || {
  echo 'vim requires vim-runtime to populate the release staging root first' >&2
  exit 66
}
output=$(tdvp_buildroot_output_from_sdk "$sdk_root" "$configured_output")
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; exit 67; }

payload_dir=
payload_link="$package_dir/root"
payload_ready=0
temporary_prefix=/tmp/tdvp-command-payload.
cleanup() {
  local rc=$?
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$payload_link" && "$(readlink -f -- "$payload_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$payload_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

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
install -Dm 0755 "$stage_root/usr/bin/vim" "$payload_dir/usr/libexec/tdvp-vim/vim"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/libexec/tdvp-vim/vim"
install -d -m 0755 "$payload_dir/usr/bin"
cat >"$payload_dir/usr/bin/vim" <<'EOF'
#!/bin/sh
exec /usr/libexec/tdvp-vim/vim "$@"
EOF
chmod 0755 "$payload_dir/usr/bin/vim"
install -Dm 0644 "$package_dir/vimrc" "$payload_dir/etc/vimrc"
install -Dm 0644 "$package_dir/tdvp-vim.desktop" "$payload_dir/usr/share/applications/tdvp-vim.desktop"
payload_ready=1
echo "vim payload ready: $payload_dir"
