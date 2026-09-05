#!/usr/bin/env bash
# Build one GNU coreutils multi-call ELF from its locked Buildroot source and
# publish only collision-free TDVP wrappers. The firmware's /bin and /usr/bin
# commands remain untouched.
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

output=$(tdvp_buildroot_output_from_sdk "$4" "${TDVP_DEVEL_BUILDROOT_OUTPUT:-}")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; exit 65; }

grep -Fqx 'COREUTILS_VERSION = 9.5' "$tree/package/coreutils/coreutils.mk" || {
  echo 'locked Buildroot coreutils recipe differs from version 9.5' >&2
  exit 66
}
grep -Fqx 'COREUTILS_CONF_OPTS += --enable-single-binary=symlinks' "$tree/package/coreutils/coreutils.mk" || {
  echo 'reviewed Buildroot coreutils recipe no longer selects the multi-call payload' >&2
  exit 67
}

download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
install_root=$(mktemp -d)
payload_dir=
payload_ready=0
root_link="$package_dir/root"
temporary_prefix="${TMPDIR:-/tmp}/tdvp-coreutils-payload."
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

# Do not inherit feature branches that would introduce non-ABI target
# providers into the candidate. Each requested command still comes from one
# locked GNU source archive and one matching Buildroot transaction.
tdvp_buildroot_install "$output" "$install_root" \
  --offline-download-dir "$download_dir" \
  --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  --enable BR2_PACKAGE_COREUTILS \
  --disable BR2_PACKAGE_ACL \
  --disable BR2_PACKAGE_ATTR \
  --disable BR2_PACKAGE_LIBCAP \
  --disable BR2_PACKAGE_LIBSELINUX \
  --disable BR2_PACKAGE_OPENSSL \
  --disable BR2_ENABLE_LOCALE \
  --target coreutils

coreutils_elf="$install_root/usr/bin/coreutils"
[[ -f "$coreutils_elf" && -x "$coreutils_elf" && ! -L "$coreutils_elf" ]] || {
  echo 'coreutils target install omitted the expected /usr/bin/coreutils multi-call ELF' >&2
  exit 68
}

# Keep to commands Buildroot explicitly lists in COREUTILS_BIN_PROGS, plus
# chroot whose recipe deliberately relocates it to /usr/sbin. Every public
# name is prefixed, even where the firmware currently lacks that command.
commands=(
  base64 cat chgrp chmod chown cp date dd df dir echo false kill link ln ls
  mkdir mknod mktemp mv nice printenv pwd rm rmdir vdir sleep stty sync touch
  true uname join chroot
)

has_installed_applet() {
  local command=$1 candidate
  for candidate in "/bin/$command" "/usr/bin/$command" "/usr/sbin/$command"; do
    [[ -e "$install_root$candidate" ]] && return 0
  done
  return 1
}

for command in "${commands[@]}"; do
  has_installed_applet "$command" || {
    echo "coreutils target install omitted approved applet: $command" >&2
    exit 69
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
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/libexec/tdvp-coreutils"
install -Dm 0755 "$coreutils_elf" "$payload_dir/usr/libexec/tdvp-coreutils/coreutils"
tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/libexec/tdvp-coreutils/coreutils"

for command in "${commands[@]}"; do
  # GNU coreutils' single binary selects an applet from argv[0], unlike
  # BusyBox's optional `busybox <applet>` form. Keep one private relative
  # symlink per selected applet so the target program receives the reviewed
  # command basename without adding a second ELF or a public firmware path.
  ln -s -- coreutils "$payload_dir/usr/libexec/tdvp-coreutils/$command"
  cat >"$payload_dir/usr/bin/tdvp-coreutils-$command" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-coreutils/$command "\$@"
EOF
  chmod 0755 -- "$payload_dir/usr/bin/tdvp-coreutils-$command"
done

payload_ready=1
echo "coreutils payload ready: $payload_dir"
