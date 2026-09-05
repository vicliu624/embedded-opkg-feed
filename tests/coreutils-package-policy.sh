#!/usr/bin/env bash
# Keep GNU coreutils a single locked multi-call ELF behind explicit TDVP names.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/coreutils"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing coreutils policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='coreutils'$" "$package_dir/package.env"
expect_line "^VERSION='9[.]5-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='GNU coreutils'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='9[.]5'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='coreutils-9[.]5[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='cd328edeac92f6a665de9f323c93b712af1858bc2e0d88f3f7100469470a1b8a'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line "COREUTILS_VERSION = 9[.]5" "$build_file"
expect_line "--enable BR2_PACKAGE_COREUTILS" "$build_file"
expect_line "--make-variable 'COREUTILS_CONF_OPTS=--disable-rpath --enable-single-binary --disable-acl --disable-xattr --disable-libcap --without-selinux --without-openssl --disable-nls'" "$build_file"
if grep -Eq -- '--disable BR2_(PACKAGE_ACL|PACKAGE_ATTR|PACKAGE_LIBCAP|PACKAGE_LIBSELINUX|PACKAGE_OPENSSL|ENABLE_LOCALE)' "$build_file"; then
  echo 'coreutils must not modify a global TDVP Kconfig provider choice' >&2
  exit 1
fi
expect_line "/usr/libexec/tdvp-coreutils/coreutils" "$build_file"
expect_line "tdvp-coreutils-" "$build_file"
expect_line "ln -s -- coreutils" "$build_file"
expect_line 'exec /usr/libexec/tdvp-coreutils/\$command' "$build_file"
expect_line "coreutils target install omitted approved applet" "$build_file"
grep -Fq '"$target_root/usr/sbin"' "$repo_root/support/buildroot-feed-session.sh"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'coreutils build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, nodejs]' "$workflow"
grep -Fq 'coreutils-tools)' "$workflow"
grep -Fq 'package_args=(--package coreutils)' "$workflow"
grep -Fq 'expected_packages=(coreutils)' "$workflow"
grep -Fq 'bash ./tests/coreutils-package-policy.sh' "$workflow"

echo 'isolated GNU coreutils policy: PASS'
