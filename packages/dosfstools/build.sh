#!/usr/bin/env bash
# Build locked dosfstools with Buildroot and expose only explicit TDVP names.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

output=$(tdvp_buildroot_output_from_sdk "$4" "${TDVP_DOSFSTOOLS_BUILDROOT_OUTPUT:-}")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; exit 65; }
grep -Fqx 'DOSFSTOOLS_VERSION = 4.2' "$tree/package/dosfstools/dosfstools.mk" || {
  echo 'locked Buildroot dosfstools recipe differs from version 4.2' >&2
  exit 66
}

download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
install_root=$(mktemp -d)
payload_dir=
payload_ready=0
root_link="$package_dir/root"
temporary_prefix="${TMPDIR:-/tmp}/tdvp-dosfstools-payload."
cleanup() {
  local rc=$?
  rm -rf -- "$install_root" "$download_dir"
  if [[ "$payload_ready" -eq 0 && -n "$payload_dir" && -d "$payload_dir" ]]; then
    rm -rf -- "$payload_dir"
    if [[ -L "$root_link" && "$(readlink -f -- "$root_link" 2>/dev/null || true)" == "$payload_dir" ]]; then
      rm -f -- "$root_link"
    fi
  fi
  exit "$rc"
}
trap cleanup EXIT

tdvp_buildroot_install "$output" "$install_root" \
  --offline-download-dir "$download_dir" \
  --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  --enable BR2_PACKAGE_DOSFSTOOLS \
  --enable BR2_PACKAGE_DOSFSTOOLS_FATLABEL \
  --enable BR2_PACKAGE_DOSFSTOOLS_FSCK_FAT \
  --enable BR2_PACKAGE_DOSFSTOOLS_MKFS_FAT \
  --target dosfstools

commands=(fatlabel fsck.fat mkfs.fat)
for command in "${commands[@]}"; do
  [[ -f "$install_root/sbin/$command" && -x "$install_root/sbin/$command" && ! -L "$install_root/sbin/$command" ]] || {
    echo "dosfstools target install omitted approved command: $command" >&2
    exit 67
  }
done

if [[ -L "$root_link" ]]; then
  previous_payload=$(readlink -f -- "$root_link" 2>/dev/null || true)
  if [[ "$previous_payload" == "$temporary_prefix"* && -d "$previous_payload" ]]; then
    rm -rf -- "$previous_payload"
  fi
fi
rm -rf -- "$root_link"
payload_dir=$(mktemp -d "${temporary_prefix}XXXXXX")
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$root_link"
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/libexec/tdvp-dosfstools"

for command in "${commands[@]}"; do
  install -Dm 0755 "$install_root/sbin/$command" "$payload_dir/usr/libexec/tdvp-dosfstools/$command"
  tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/libexec/tdvp-dosfstools/$command"
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/libexec/tdvp-dosfstools/$command"
done

cat >"$payload_dir/usr/bin/tdvp-dosfstools-fatlabel" <<'EOF'
#!/bin/sh
exec /usr/libexec/tdvp-dosfstools/fatlabel "$@"
EOF
cat >"$payload_dir/usr/bin/tdvp-dosfstools-fsck-fat" <<'EOF'
#!/bin/sh
exec /usr/libexec/tdvp-dosfstools/fsck.fat "$@"
EOF
cat >"$payload_dir/usr/bin/tdvp-dosfstools-mkfs-fat" <<'EOF'
#!/bin/sh
exec /usr/libexec/tdvp-dosfstools/mkfs.fat "$@"
EOF
chmod 0755 -- "$payload_dir/usr/bin/tdvp-dosfstools-fatlabel" \
  "$payload_dir/usr/bin/tdvp-dosfstools-fsck-fat" \
  "$payload_dir/usr/bin/tdvp-dosfstools-mkfs-fat"

payload_ready=1
echo "dosfstools payload ready: $payload_dir"
