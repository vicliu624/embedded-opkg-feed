#!/usr/bin/env bash
# Keep the network diagnostic small: a private command with no silent TLS or
# host-ABI runtime imports.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/iperf3"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing iperf3 policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='iperf3'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]18-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_SECTION='net'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='iperf3'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='3[.]18'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='iperf-3[.]18[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line 'optional OpenSSL authentication mode is explicitly disabled' "$package_dir/source.lock"
expect_line 'does not fetch host-pkgconf or OpenSSL source inputs' "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'BR2_TOOLCHAIN_HAS_ATOMIC=y BR2_TOOLCHAIN_HAS_THREADS=y' "$build_file"
expect_line 'IPERF3_CONF_OPTS=--without-openssl --disable-shared --enable-static' "$build_file"
expect_line "IPERF3_DEPENDENCIES='" "$build_file"
expect_line 'do not alter that global Kconfig' "$build_file"
expect_line 'IPERF3_VERSION = 3[.]18' "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'iperf3 build must not import a Debian package or binary' >&2
  exit 1
fi

helper="$repo_root/support/buildroot-command-package.sh"
expect_line 'BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$helper"
expect_line 'TDVP_COMMAND_BUILDROOT_MAKE_VARIABLES' "$helper"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$helper"

echo 'locked-source bounded iperf3 policy: PASS'
