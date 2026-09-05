#!/usr/bin/env bash
# Keep GNU cpio a private archive command with no provider ABI or CI I/O.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/cpio"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || { echo "missing cpio policy entry in $path: $pattern" >&2; exit 1; }
}

expect_line "^PACKAGE='cpio'\$" "$package_dir/package.env"
expect_line "^VERSION='2[.]15-1'\$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''\$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''\$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1\$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'\$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='GNU cpio'\$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='cpio-2[.]15[.]tar[.]bz2'\$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='937610b97c329a1ec9268553fb780037bcfff0dcffe9725ebc4fd9c1aa9075db'\$" "$package_dir/source.lock"

grep -Fq 'cpio=tdvp-cpio' "$package_dir/build.sh"
grep -Fq "'cpio'" "$package_dir/build.sh"
if grep -Eq '/usr/(s)?bin/cpio|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'cpio build must not publish ordinary paths or import Debian inputs' >&2
  exit 1
fi

grep -Fq 'cpio-archive-tools)' "$workflow"
grep -Fq 'package_args=(--package cpio)' "$workflow"
grep -Fq 'expected_packages=(cpio)' "$workflow"
grep -Fq 'bash ./tests/cpio-package-policy.sh' "$workflow"
echo 'locked private GNU cpio policy: PASS'
