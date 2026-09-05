#!/usr/bin/env bash
# Keep GNU time a private process-accounting command with no provider ABI.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/time"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || { echo "missing time policy entry in $path: $pattern" >&2; exit 1; }
}

expect_line "^PACKAGE='time'\$" "$package_dir/package.env"
expect_line "^VERSION='1[.]9-1'\$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''\$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''\$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1\$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'\$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='GNU time'\$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='time-1[.]9[.]tar[.]gz'\$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='fbacf0c81e62429df3e33bda4cee38756604f18e01d977338e23306a3e3b521e'\$" "$package_dir/source.lock"

grep -Fq 'time=tdvp-time' "$package_dir/build.sh"
grep -Fq "'time'" "$package_dir/build.sh"
if grep -Eq '/usr/(s)?bin/time|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'time build must not publish ordinary paths or import Debian inputs' >&2
  exit 1
fi

grep -Fq 'process-timing-tools)' "$workflow"
grep -Fq 'package_args=(--package time)' "$workflow"
grep -Fq 'expected_packages=(time)' "$workflow"
grep -Fq 'bash ./tests/time-package-policy.sh' "$workflow"
echo 'locked private GNU time policy: PASS'
