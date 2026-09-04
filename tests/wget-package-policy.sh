#!/usr/bin/env bash
# Keep Wget in the reviewed OpenSSL/zlib closure; do not make an optional
# desktop Buildroot feature become a silent TDVP feed runtime dependency.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/wget"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing Wget policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='wget'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]25[.]0-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_SECTION='net'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='ca-certificates \\(= 2025[.]02[.]1-1\\), libssl-3 \\(= 3[.]4[.]1-1\\), libcrypto-3 \\(= 3[.]4[.]1-1\\), libz \\(= 1[.]3[.]1-1\\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='ca-certificates libssl-3 libcrypto-3 libz'$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='GNU Wget'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='1[.]25[.]0'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='wget-1[.]25[.]0[.]tar[.]lz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_FILE='pkgconf-2[.]3[.]0[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line 'optional PSL, GnuTLS, IDN/IRI, c-ares, PCRE, and libuuid closures are disabled' "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'BR2_PACKAGE_OPENSSL=y BR2_PACKAGE_LIBOPENSSL=y BR2_PACKAGE_ZLIB=y' "$build_file"
expect_line 'WGET_VERSION = 1[.]25[.]0' "$build_file"
expect_line 'BR2_PACKAGE_LIBPSL BR2_PACKAGE_GNUTLS BR2_PACKAGE_LIBIDN2 BR2_PACKAGE_C_ARES' "$build_file"
expect_line 'BR2_PACKAGE_PCRE BR2_PACKAGE_PCRE2 BR2_PACKAGE_UTIL_LINUX_LIBUUID' "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'Wget build must not import a Debian package or binary' >&2
  exit 1
fi

helper="$repo_root/support/buildroot-command-package.sh"
expect_line 'BR2_PACKAGE_BUSYBOX_SHOW_OTHERS' "$helper"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$helper"

echo 'locked-source OpenSSL/zlib Wget policy: PASS'
