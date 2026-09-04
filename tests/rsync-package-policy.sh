#!/usr/bin/env bash
# Keep rsync bounded to popt/zlib and the explicit SSH transport provider.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/rsync"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing rsync policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='rsync'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]4[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libpopt \\(= 1[.]19-1\\), libz \\(= 1[.]3[.]1-1\\), openssh-client \\(= 9[.]9p2-1\\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libpopt libz openssh-client'$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='rsync'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='3[.]4[.]1'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='rsync-3[.]4[.]1[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_FILE='popt-1[.]19[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_3_FILE='zlib-1[.]3[.]1[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_4_FILE='pkgconf-2[.]3[.]0[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_PATCH_1_FILE='patches/0001-configure[.]ac-use-pkg-config-to-retrieve-openssl-depe[.]patch'$" "$package_dir/source.lock"
test -f "$package_dir/patches/0001-configure.ac-use-pkg-config-to-retrieve-openssl-depe.patch"

build_file="$package_dir/build.sh"
expect_line "BR2_PACKAGE_ZLIB=y" "$build_file"
expect_line 'RSYNC_VERSION = 3[.]4[.]1' "$build_file"
expect_line 'BR2_PACKAGE_ACL BR2_PACKAGE_LZ4 BR2_PACKAGE_OPENSSL BR2_PACKAGE_XXHASH BR2_PACKAGE_ZSTD' "$build_file"
expect_line 'normalised_patch_sha256' "$build_file"
expect_line 'could not normalize the locked rsync patch' "$build_file"
expect_line 'could not normalize the matching Buildroot rsync patch' "$build_file"
expect_line 'locked rsync patch differs from the matching Buildroot tree' "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'rsync build must not import a Debian package or binary' >&2
  exit 1
fi

echo 'locked-source rsync/popt/zlib/ssh policy: PASS'
