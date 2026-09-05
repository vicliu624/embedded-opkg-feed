#!/usr/bin/env bash
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/xxhash"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='xxhash'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='aae608dfe8213dfd05d909a57718ef82f30722c392344583d3f39050c7f29a80'" "$package_dir/source.lock"
grep -Fq 'non-cryptographic checksum command' "$package_dir/source.lock"
grep -Fq 'must never be used for authentication' "$package_dir/source.lock"
grep -Fq 'XXHASH_TARGETS=xxhsum' "$package_dir/build.sh"
grep -Fq 'XXHASH_INSTALL_TARGETS=install_xxhsum' "$package_dir/build.sh"
grep -Fq 'xxhsum=tdvp-xxhsum' "$package_dir/build.sh"
grep -Fq 'fast-integrity-tools)' "$workflow"
grep -Fq 'package_args=(--package xxhash)' "$workflow"
grep -Fq 'bash ./tests/xxhash-package-policy.sh' "$workflow"
echo 'locked private xxhash policy: PASS'
