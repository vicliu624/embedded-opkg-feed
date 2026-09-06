#!/usr/bin/env bash
# Keep pigz a private command consumer of the existing zlib provider.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/pigz"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='pigz'" "$package_dir/package.env"
grep -Fqx "VERSION='2.8-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "PACKAGE_AUTO_RUNTIME_DEPENDS=1" "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_URL='https://mirrors.omnios.org/pigz/pigz-2.8.tar.gz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='eb872b4f0e1f0ebe59c9f7bd8c506c4204893ba6a8492de31df416f0d5170fd0'" "$package_dir/source.lock"
grep -Fq 'do not authenticate content' "$package_dir/source.lock"
grep -Fq '34001374220 received non-archive content' "$package_dir/source.lock"
grep -Fq "PIGZ_VERSION = 2.8" "$package_dir/build.sh"
grep -Fq 'pigz=tdvp-pigz' "$package_dir/build.sh"
grep -Fq "'pigz'" "$package_dir/build.sh"
if grep -Eq '/usr/bin/pigz|unpigz|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'pigz recipe must not publish an ordinary path or import Debian inputs' >&2
  exit 1
fi

grep -Fq 'parallel-gzip-tools)' "$workflow"
grep -Fq 'package_args=(--package pigz)' "$workflow"
grep -Fq 'expected_packages=(pigz)' "$workflow"
grep -Fq 'bash ./tests/pigz-package-policy.sh' "$workflow"

echo 'locked private pigz policy: PASS'
