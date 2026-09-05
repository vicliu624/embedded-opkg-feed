#!/usr/bin/env bash
# Keep jo a private JSON-construction command with no provider ABI.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/jo"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || { echo "missing jo policy entry in $path: $pattern" >&2; exit 1; }
}

expect_line "^PACKAGE='jo'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]6-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='jo'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='jo-1[.]6[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='eb15592f1ba6d5a77468a1438a20e3d21c3d63bb7d045fb3544f223340fcd1a1'$" "$package_dir/source.lock"

grep -Fq 'jo=tdvp-jo' "$package_dir/build.sh"
grep -Fq "'jo'" "$package_dir/build.sh"
if grep -Eq '/usr/(s)?bin/jo|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'jo build must not publish ordinary paths or import Debian inputs' >&2; exit 1
fi

grep -Fq 'json-construction-tools)' "$workflow"
grep -Fq 'package_args=(--package jo)' "$workflow"
grep -Fq 'expected_packages=(jo)' "$workflow"
grep -Fq 'bash ./tests/jo-package-policy.sh' "$workflow"
echo 'locked private jo policy: PASS'
