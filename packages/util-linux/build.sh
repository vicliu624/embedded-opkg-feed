#!/usr/bin/env bash
# Build a deliberately narrow util-linux command cohort from the locked
# Buildroot recipe. All public entry points stay in the TDVP namespace.
set -Eeuo pipefail
IFS=$'\n\t'

[[ $# -eq 4 && "$1" == '--platform' && "$2" == 'tdvp-k230-r1' && "$3" == '--sdk-root' ]] || {
  echo 'usage: build.sh --platform tdvp-k230-r1 --sdk-root <host>' >&2
  exit 64
}

package_dir=$(cd -- "$(dirname -- "$BASH_SOURCE")" && pwd)
# shellcheck source=../../support/buildroot-feed-session.sh
source "$package_dir/../../support/buildroot-feed-session.sh"
# shellcheck source=../../support/elf-runtime-policy.sh
source "$package_dir/../../support/elf-runtime-policy.sh"

output_override=
if [[ -v TDVP_UTIL_LINUX_BUILDROOT_OUTPUT ]]; then
  output_override=$TDVP_UTIL_LINUX_BUILDROOT_OUTPUT
fi
output=$(tdvp_buildroot_output_from_sdk "$4" "$output_override")
tree=$(tdvp_buildroot_tree_from_output "$output")
tdvp_assert_buildroot_2025_02_1 "$tree"
readelf_tool="$output/host/bin/riscv64-unknown-linux-gnu-readelf"
[[ -x "$readelf_tool" ]] || { echo "matching SDK has no target readelf: $readelf_tool" >&2; exit 65; }
grep -Fqx 'UTIL_LINUX_VERSION_MAJOR = 2.40' "$tree/package/util-linux/util-linux.mk" || {
  echo 'locked Buildroot util-linux recipe differs from major version 2.40' >&2
  exit 66
}
grep -Fqx 'UTIL_LINUX_VERSION = $(UTIL_LINUX_VERSION_MAJOR).2' "$tree/package/util-linux/util-linux.mk" || {
  echo 'locked Buildroot util-linux recipe differs from version 2.40.2' >&2
  exit 66
}

download_dir=$(tdvp_prepare_locked_buildroot_download "$package_dir")
install_root=$(mktemp -d)
payload_dir=
payload_ready=0
root_link="$package_dir/root"
if [[ ! -v TMPDIR ]]; then
  TMPDIR=/tmp
fi
temporary_prefix="$TMPDIR/tdvp-util-linux-payload."
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

# The parent feature is required by Buildroot. The individually enabled
# commands below deliberately avoid util-linux's libblkid/libfdisk/libmount/
# libsmartcols/libuuid feature families, so this first cohort does not create
# an undeclared shared-library ABI provider. NLS is disabled per this private
# make transaction rather than by changing the immutable firmware Kconfig.
tdvp_buildroot_install "$output" "$install_root" \
  --offline-download-dir "$download_dir" \
  --enable BR2_PACKAGE_BUSYBOX_SHOW_OTHERS \
  --enable BR2_PACKAGE_UTIL_LINUX \
  --enable BR2_PACKAGE_UTIL_LINUX_CAL \
  --enable BR2_PACKAGE_UTIL_LINUX_FALLOCATE \
  --enable BR2_PACKAGE_UTIL_LINUX_IPCMK \
  --enable BR2_PACKAGE_UTIL_LINUX_IPCRM \
  --enable BR2_PACKAGE_UTIL_LINUX_IPCS \
  --enable BR2_PACKAGE_UTIL_LINUX_KILL \
  --enable BR2_PACKAGE_UTIL_LINUX_LAST \
  --enable BR2_PACKAGE_UTIL_LINUX_LINE \
  --enable BR2_PACKAGE_UTIL_LINUX_LOGGER \
  --enable BR2_PACKAGE_UTIL_LINUX_MESG \
  --enable BR2_PACKAGE_UTIL_LINUX_NOLOGIN \
  --enable BR2_PACKAGE_UTIL_LINUX_NSENTER \
  --enable BR2_PACKAGE_UTIL_LINUX_PIVOT_ROOT \
  --enable BR2_PACKAGE_UTIL_LINUX_RENAME \
  --enable BR2_PACKAGE_UTIL_LINUX_SCHEDUTILS \
  --enable BR2_PACKAGE_UTIL_LINUX_UNSHARE \
  --enable BR2_PACKAGE_UTIL_LINUX_UTMPDUMP \
  --enable BR2_PACKAGE_UTIL_LINUX_WAITPID \
  --enable BR2_PACKAGE_UTIL_LINUX_WALL \
  --enable BR2_PACKAGE_UTIL_LINUX_WRITE \
  --make-variable 'UTIL_LINUX_CONF_OPTS=--disable-nls --disable-liblastlog2' \
  --target util-linux

# Keep only an explicit, reviewable command boundary. Partition, mount,
# filesystem, loop-device, wipe, setuid/login and shared-library features are
# not selected here; a future library/provider cohort must admit them first.
commands=(
  cal fallocate ipcmk ipcrm ipcs kill last line logger mesg nologin nsenter
  pivot_root rename chrt ionice taskset uclampset unshare utmpdump waitpid
  wall write
)
for command in "${commands[@]}"; do
  source=
  for candidate in "/usr/bin/$command" "/usr/sbin/$command" "/bin/$command" "/sbin/$command"; do
    if [[ -f "$install_root$candidate" && -x "$install_root$candidate" && ! -L "$install_root$candidate" ]]; then
      source="$install_root$candidate"
      break
    fi
  done
  [[ -n "$source" ]] || {
    echo "util-linux target install omitted approved command: $command" >&2
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
payload_dir=$(mktemp -d "$temporary_prefix"XXXXXX)
chmod 0755 -- "$payload_dir"
ln -s -- "$payload_dir" "$root_link"
mkdir -p -- "$payload_dir/usr/bin" "$payload_dir/usr/libexec/tdvp-util-linux"

for command in "${commands[@]}"; do
  source=
  for candidate in "/usr/bin/$command" "/usr/sbin/$command" "/bin/$command" "/sbin/$command"; do
    if [[ -f "$install_root$candidate" && -x "$install_root$candidate" && ! -L "$install_root$candidate" ]]; then
      source="$install_root$candidate"
      break
    fi
  done
  install -Dm 0755 "$source" "$payload_dir/usr/libexec/tdvp-util-linux/$command"
  tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$payload_dir/usr/libexec/tdvp-util-linux/$command"
  tdvp_assert_elf_without_runtime_search_path "$readelf_tool" "$payload_dir/usr/libexec/tdvp-util-linux/$command"
  cat >"$payload_dir/usr/bin/tdvp-util-linux-$command" <<EOF
#!/bin/sh
exec /usr/libexec/tdvp-util-linux/$command "\$@"
EOF
  chmod 0755 -- "$payload_dir/usr/bin/tdvp-util-linux-$command"
done

payload_ready=1
echo "util-linux payload ready: $payload_dir"
