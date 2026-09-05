#!/usr/bin/env bash
# Keep the source-navigation cohort a closed set of locked-source command
# packages.  Its public surface must remain TDVP-prefixed and it may only use
# runtime providers already owned by the reviewed r10 catalogue.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing source-navigation candidate policy entry in $path: $pattern" >&2
    exit 1
  }
}

for package in which findutils diffutils grep sed gawk; do
  package_dir="$repo_root/packages/$package"
  expect_line "^PACKAGE='$package'$" "$package_dir/package.env"
  expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
  expect_line "^PACKAGE_RELEASES='.*r10.*'$" "$package_dir/package.env"
  expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
  test -f "$package_dir/source.lock"
done

expect_line "TDVP_COMMAND_FRONTEND_NAMES='which=tdvp-which'" "$repo_root/packages/which/build.sh"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='find=tdvp-find xargs=tdvp-xargs'" "$repo_root/packages/findutils/build.sh"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='diff=tdvp-diff cmp=tdvp-cmp diff3=tdvp-diff3 sdiff=tdvp-sdiff'" "$repo_root/packages/diffutils/build.sh"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='grep=tdvp-grep'" "$repo_root/packages/grep/build.sh"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='sed=tdvp-sed'" "$repo_root/packages/sed/build.sh"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='gawk=tdvp-gawk awk=tdvp-awk'" "$repo_root/packages/gawk/build.sh"
expect_line "^PACKAGE_DEPENDS='libpcre2-8 \\(= 10[.]44-1\\)'$" "$repo_root/packages/grep/package.env"
expect_line "^PACKAGE_DEPENDS='libreadline \\(= 8[.]2-1\\)'$" "$repo_root/packages/gawk/package.env"
expect_line "^libpcre2-8[.]so[.]0\\|libpcre2-8\\|10[.]44-1$" "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
expect_line "^libreadline[.]so[.]8\\|libreadline\\|8[.]2-1$" "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

grep -Fq 'source-navigation-tools)' "$workflow"
grep -Fq 'package_args=(--package which --package findutils --package diffutils --package grep --package sed --package gawk)' "$workflow"
grep -Fq 'expected_packages=(which findutils diffutils grep sed gawk)' "$workflow"
grep -Fq 'bash ./tests/source-navigation-tools-package-policy.sh' "$workflow"

echo 'source-built source-navigation candidate policy: PASS'
