#!/usr/bin/env bash
# Keep source-built memory diagnostics private and operationally explicit.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/memtester"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing memtester policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='memtester'$" "$package_dir/package.env"
expect_line "^VERSION='4[.]5[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='memtester'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='4[.]5[.]1'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='memtester-4[.]5[.]1[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='1c5fc2382576c084b314cfd334d127a66c20bd63892cac9f445bc1d8b4ca5a47'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'MEMTESTER_VERSION = 4[.]5[.]1' "$build_file"
grep -Fq 'BR2_PACKAGE_MEMTESTER' "$build_file"
grep -Fq 'tdvp_buildroot_command_package' "$build_file"
grep -Fq "'memtester'" "$build_file"
grep -Fq 'tdvp-memtester' "$build_file"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'memtester build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, directory-tree-tools, system-tools, nodejs]' "$workflow"
grep -Fq 'memory-diagnostic-tools)' "$workflow"
grep -Fq 'package_args=(--package memtester)' "$workflow"
grep -Fq 'expected_packages=(memtester)' "$workflow"
grep -Fq 'bash ./tests/memtester-package-policy.sh' "$workflow"

echo 'isolated memtester policy: PASS'
