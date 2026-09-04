#!/usr/bin/env bash
# Netcat may be a small command, but it still needs a fixed source, an
# independently owned private implementation, and no Debian/binary import.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/netcat"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing netcat policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='netcat'$" "$package_dir/package.env"
expect_line "^VERSION='0[.]7[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_SECTION='net'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='GNU Netcat'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='0[.]7[.]1'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='netcat-0[.]7[.]1[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line 'no optional target runtime closure beyond the platform ABI' "$package_dir/source.lock"
expect_line 'controlled endpoints' "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'NETCAT_VERSION = 0[.]7[.]1' "$build_file"
expect_line "'nc'" "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'netcat build must not import a Debian package or binary' >&2
  exit 1
fi

helper="$repo_root/support/buildroot-command-package.sh"
expect_line 'BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$helper"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$helper"

echo 'locked-source bounded netcat policy: PASS'
