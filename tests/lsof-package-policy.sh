#!/usr/bin/env bash
# Keep lsof as a small /proc inspector: no copied SDK RPC library and no
# Debian package/binary import.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/lsof"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing lsof policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='lsof'$" "$package_dir/package.env"
expect_line "^VERSION='4[.]99[.]4-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_SECTION='devel'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='lsof'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='4[.]99[.]4'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='lsof-4[.]99[.]4[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line 'optional libtirpc linkage is explicitly disabled' "$package_dir/source.lock"
expect_line 'no extra third-party target or host dependency archive' "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line "BR2_USE_MMU=y" "$build_file"
expect_line "BR2_PACKAGE_LIBTIRPC" "$build_file"
expect_line "LSOF_VERSION = 4[.]99[.]4" "$build_file"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='lsof=tdvp-lsof'" "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'lsof build must not import a Debian package or binary' >&2
  exit 1
fi

helper="$repo_root/support/buildroot-command-package.sh"
expect_line 'BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$helper"
expect_line 'TDVP_COMMAND_FRONTEND_NAMES' "$helper"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$helper"

echo 'locked-source bounded lsof policy: PASS'
