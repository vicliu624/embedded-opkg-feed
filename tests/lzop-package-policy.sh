#!/usr/bin/env bash
# LZOP is a command-only leaf: its LZO implementation and public command name
# stay private until an explicitly authorized device lifecycle validates it.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/lzop"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='lzop'" "$package_dir/package.env"
grep -Fqx "VERSION='1.04-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "PACKAGE_BUILD_DEPENDS=''" "$package_dir/package.env"
grep -Fqx 'PACKAGE_AUTO_RUNTIME_DEPENDS=1' "$package_dir/package.env"
grep -Fqx "PACKAGE_BASE_OVERLAY='deny'" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_URL='https://www.oberhumer.com/opensource/lzo/download/lzo-2.10.tar.gz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='c0f892943208266f9b6543b3ae308fab6284c5c90e627931446fb49b4221a072'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_2_URL='https://www.lzop.org/download/lzop-1.04.tar.gz'" "$package_dir/source.lock"
grep -Fqx "SOURCE_ARTIFACT_2_SHA256='7e72b62a8a60aff5200a047eea0773a8fb205caf7acbe1774d95147f305a2f41'" "$package_dir/source.lock"
grep -Fq 'LZO_CONF_OPTS=-DENABLE_SHARED=OFF -DENABLE_STATIC=ON' "$package_dir/build.sh"
grep -Fq "TDVP_COMMAND_FRONTEND_NAMES='lzop=tdvp-lzop'" "$package_dir/build.sh"
grep -Fq 'BR2_PACKAGE_LZOP lzop' "$package_dir/build.sh"
grep -Fq "'lzop'" "$package_dir/build.sh"
if sed '/^[[:space:]]*#/d' "$package_dir/build.sh" | grep -Eq '/usr/bin/lzop|liblzo2[.]so|apt|dpkg|debian'; then
  echo 'lzop recipe must not publish ordinary paths, shared ABI, or Debian inputs' >&2
  exit 1
fi

grep -Fq 'parallel-lzo-tools)' "$workflow"
grep -Fq 'package_args=(--package lzop)' "$workflow"
grep -Fq 'expected_packages=(lzop)' "$workflow"
grep -Fq 'bash ./tests/lzop-package-policy.sh' "$workflow"

echo 'locked private lzop policy: PASS'
