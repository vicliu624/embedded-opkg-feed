#!/usr/bin/env bash
# Keep the terminal pager a one-command candidate with an explicit ncurses ABI.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/less"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing less candidate policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='less'$" "$package_dir/package.env"
expect_line "^VERSION='661-2'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libncursesw \(= 6[.]4-20230603-1\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libncursesw'$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='less=tdvp-less'" "$package_dir/build.sh"
expect_line "BR2_PACKAGE_LESS less 'LESS_VERSION = 661' 'less'" "$package_dir/build.sh"
expect_line "^UPSTREAM_NAME='less'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_URL='https://www[.]greenwoodsoftware[.]com/less/less-661[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='2b5f0167216e3ef0ffcb0c31c374e287eb035e4e223d5dae315c2783b6e738ed'$" "$package_dir/source.lock"

grep -Fq 'terminal-pager-tools' "$workflow"
grep -Fq 'package_args=(--package less)' "$workflow"
grep -Fq 'expected_packages=(less)' "$workflow"
grep -Fq 'bash ./tests/less-package-policy.sh' "$workflow"

echo 'source-built terminal pager candidate policy: PASS'
