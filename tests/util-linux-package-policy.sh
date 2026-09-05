#!/usr/bin/env bash
# Keep the first util-linux cohort narrow, source-built, and collision-free.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "$BASH_SOURCE")/.." && pwd)
package_dir="$repo_root/packages/util-linux"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing util-linux policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='util-linux-tools'$" "$package_dir/package.env"
expect_line "^VERSION='2[.]40[.]2-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='util-linux'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='2[.]40[.]2'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='util-linux-2[.]40[.]2[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='d78b37a66f5922d70edf3bdfb01a6b33d34ed3c3cafd6628203b2a2b67c8e8b3'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'UTIL_LINUX_VERSION_MAJOR = 2[.]40' "$build_file"
expect_line 'UTIL_LINUX_VERSION = \$\(UTIL_LINUX_VERSION_MAJOR\)[.]2' "$build_file"
grep -Fq 'util_linux_conf_opts=(' "$build_file"
grep -Fq 'UTIL_LINUX_CONF_OPTS=$util_linux_conf_opts' "$build_file"
for configure_option in \
  --disable-rpath --disable-makeinstall-chown --disable-year2038 \
  --disable-nls --disable-liblastlog2 \
  --without-systemd --without-udev \
  --disable-widechar --without-ncurses --without-ncursesw --without-selinux \
  --without-python --disable-pylibmount --without-readline --without-audit \
  --without-libmagic \
  --disable-libblkid --disable-libfdisk --disable-libmount \
  --disable-libsmartcols --disable-libuuid --disable-all-programs \
  --enable-cal --enable-fallocate --enable-ipcmk --enable-ipcrm --enable-ipcs \
  --enable-kill --enable-last --enable-line --enable-logger --enable-mesg \
  --enable-nologin --enable-nsenter --enable-pivot_root --enable-rename \
  --enable-schedutils --enable-unshare --enable-utmpdump --enable-waitpid; do
  grep -Fq -- "$configure_option" "$build_file"
done
if grep -Fq -- '--enable-all-programs' "$build_file"; then
  echo 'util-linux narrow cohort must not enable util-linux all-programs' >&2
  exit 1
fi
for symbol in \
  BR2_PACKAGE_UTIL_LINUX \
  BR2_PACKAGE_UTIL_LINUX_CAL \
  BR2_PACKAGE_UTIL_LINUX_FALLOCATE \
  BR2_PACKAGE_UTIL_LINUX_IPCMK \
  BR2_PACKAGE_UTIL_LINUX_IPCRM \
  BR2_PACKAGE_UTIL_LINUX_IPCS \
  BR2_PACKAGE_UTIL_LINUX_KILL \
  BR2_PACKAGE_UTIL_LINUX_LAST \
  BR2_PACKAGE_UTIL_LINUX_LINE \
  BR2_PACKAGE_UTIL_LINUX_LOGGER \
  BR2_PACKAGE_UTIL_LINUX_MESG \
  BR2_PACKAGE_UTIL_LINUX_NOLOGIN \
  BR2_PACKAGE_UTIL_LINUX_NSENTER \
  BR2_PACKAGE_UTIL_LINUX_PIVOT_ROOT \
  BR2_PACKAGE_UTIL_LINUX_RENAME \
  BR2_PACKAGE_UTIL_LINUX_SCHEDUTILS \
  BR2_PACKAGE_UTIL_LINUX_UNSHARE \
  BR2_PACKAGE_UTIL_LINUX_UTMPDUMP \
  BR2_PACKAGE_UTIL_LINUX_WAITPID; do
  grep -Fq "$symbol" "$build_file"
done
for command in cal fallocate ipcmk ipcrm ipcs kill last line logger mesg nologin nsenter pivot_root rename chrt ionice taskset uclampset unshare utmpdump waitpid; do
  grep -Fq "$command" "$build_file"
done
grep -Fq 'tdvp-util-linux-$command' "$build_file"
for forbidden in \
  BR2_PACKAGE_UTIL_LINUX_BINARIES \
  BR2_PACKAGE_UTIL_LINUX_AGETTY \
  BR2_PACKAGE_UTIL_LINUX_BFS \
  BR2_PACKAGE_UTIL_LINUX_CHFN_CHSH \
  BR2_PACKAGE_UTIL_LINUX_CHMEM \
  BR2_PACKAGE_UTIL_LINUX_CRAMFS \
  BR2_PACKAGE_UTIL_LINUX_EJECT \
  BR2_PACKAGE_UTIL_LINUX_FDFORMAT \
  BR2_PACKAGE_UTIL_LINUX_FSCK \
  BR2_PACKAGE_UTIL_LINUX_HARDLINK \
  BR2_PACKAGE_UTIL_LINUX_HWCLOCK \
  BR2_PACKAGE_UTIL_LINUX_IRQTOP \
  BR2_PACKAGE_UTIL_LINUX_LIBBLKID \
  BR2_PACKAGE_UTIL_LINUX_LIBFDISK \
  BR2_PACKAGE_UTIL_LINUX_LIBMOUNT \
  BR2_PACKAGE_UTIL_LINUX_LIBSMARTCOLS \
  BR2_PACKAGE_UTIL_LINUX_LIBUUID \
  BR2_PACKAGE_UTIL_LINUX_LOGIN \
  BR2_PACKAGE_UTIL_LINUX_LOSETUP \
  BR2_PACKAGE_UTIL_LINUX_LSFD \
  BR2_PACKAGE_UTIL_LINUX_LSLOGINS \
  BR2_PACKAGE_UTIL_LINUX_LSMEM \
  BR2_PACKAGE_UTIL_LINUX_MINIX \
  BR2_PACKAGE_UTIL_LINUX_MORE \
  BR2_PACKAGE_UTIL_LINUX_MOUNT \
  BR2_PACKAGE_UTIL_LINUX_MOUNTPOINT \
  BR2_PACKAGE_UTIL_LINUX_NEWGRP \
  BR2_PACKAGE_UTIL_LINUX_PARTX \
  BR2_PACKAGE_UTIL_LINUX_PG \
  BR2_PACKAGE_UTIL_LINUX_RAW \
  BR2_PACKAGE_UTIL_LINUX_RFKILL \
  BR2_PACKAGE_UTIL_LINUX_RUNUSER \
  BR2_PACKAGE_UTIL_LINUX_SETPRIV \
  BR2_PACKAGE_UTIL_LINUX_SETTERM \
  BR2_PACKAGE_UTIL_LINUX_SU \
  BR2_PACKAGE_UTIL_LINUX_SULOGIN \
  BR2_PACKAGE_UTIL_LINUX_SWITCH_ROOT \
  BR2_PACKAGE_UTIL_LINUX_TUNELP \
  BR2_PACKAGE_UTIL_LINUX_UL \
  BR2_PACKAGE_UTIL_LINUX_UUIDD \
  BR2_PACKAGE_UTIL_LINUX_VIPW \
  BR2_PACKAGE_UTIL_LINUX_WALL \
  BR2_PACKAGE_UTIL_LINUX_WDCTL \
  BR2_PACKAGE_UTIL_LINUX_WIPEFS \
  BR2_PACKAGE_UTIL_LINUX_WRITE \
  BR2_PACKAGE_UTIL_LINUX_ZRAMCTL; do
  if grep -Fq -- "--enable $forbidden" "$build_file"; then
    echo "util-linux narrow cohort must not enable $forbidden" >&2
    exit 1
  fi
done
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'util-linux build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, system-tools, nodejs]' "$workflow"
grep -Fq 'system-tools)' "$workflow"
grep -Fq 'package_args=(--package util-linux-tools)' "$workflow"
grep -Fq 'expected_packages=(util-linux-tools)' "$workflow"
grep -Fq 'bash ./tests/util-linux-package-policy.sh' "$workflow"

echo 'isolated util-linux narrow cohort policy: PASS'
