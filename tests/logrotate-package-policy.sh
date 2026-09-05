#!/usr/bin/env bash
# Keep logrotate a private, command-only maintenance tool with no policy files.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/logrotate"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing logrotate policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='logrotate'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]22[.]0-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libpopt \(= 1[.]19-1\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libpopt'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='logrotate'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='logrotate-3[.]22[.]0[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='42b4080ee99c9fb6a7d12d8e787637d057a635194e25971997eebbe8d5e57618'$" "$package_dir/source.lock"

grep -Fq "TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_LIBSELINUX BR2_PACKAGE_ACL'" "$package_dir/build.sh"
grep -Fq 'LOGROTATE_CONF_OPTS=--without-selinux --without-acl' "$package_dir/build.sh"
grep -Fq 'logrotate=tdvp-logrotate' "$package_dir/build.sh"
grep -Fq "'logrotate'" "$package_dir/build.sh"
if grep -Eq '/etc/logrotate|/usr/(s)?bin/logrotate|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'logrotate build must not package configuration, ordinary paths, or Debian inputs' >&2
  exit 1
fi

grep -Fq 'log-maintenance-tools)' "$workflow"
grep -Fq 'package_args=(--package logrotate)' "$workflow"
grep -Fq 'expected_packages=(logrotate)' "$workflow"
grep -Fq 'bash ./tests/logrotate-package-policy.sh' "$workflow"

echo 'locked private logrotate policy: PASS'
