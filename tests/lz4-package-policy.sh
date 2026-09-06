#!/usr/bin/env bash
# LZ4 is a command-only leaf: keep its implementation and every public name
# private until an explicitly authorized device lifecycle validates it.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/lz4"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='lz4'" "$package_dir/package.env"
grep -Fqx "VERSION='1.10.0-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$package_dir/package.env"
grep -Fqx 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_URL='https://github.com/lz4/lz4/archive/refs/tags/v1.10.0.tar.gz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b'" "$package_dir/source.lock"
grep -Fq 'LZ4_MAKE_OPTS=BUILD_SHARED=no' "$package_dir/build.sh"
grep -Fq "TDVP_COMMAND_BUILDROOT_ENABLE_SYMBOLS='BR2_PACKAGE_LZ4_PROGS'" "$package_dir/build.sh"
grep -Fq 'lz4=tdvp-lz4 lz4c=tdvp-lz4c unlz4=tdvp-unlz4 lz4cat=tdvp-lz4cat' "$package_dir/build.sh"
grep -Fq "'lz4 lz4c unlz4 lz4cat'" "$package_dir/build.sh"
if sed '/^[[:space:]]*#/d' "$package_dir/build.sh" | grep -Eq '/usr/bin/lz4|liblz4[.]so|apt|dpkg|debian'; then
  echo 'lz4 recipe must not publish ordinary paths, shared ABI, or Debian inputs' >&2
  exit 1
fi

grep -Fq 'fast-lz4-tools)' "$workflow"
grep -Fq 'package_args=(--package lz4)' "$workflow"
grep -Fq 'expected_packages=(lz4)' "$workflow"
grep -Fq 'bash ./tests/lz4-package-policy.sh' "$workflow"

echo 'locked private lz4 policy: PASS'
