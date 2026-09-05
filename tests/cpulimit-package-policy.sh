#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/cpulimit"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fqx "PACKAGE='cpulimit'" "$package_dir/package.env"
grep -Fqx "VERSION='0.2-1'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='64312f9ac569ddcadb615593cd002c94b76e93a0d4625d3ce1abb49e08e2c2da'" "$package_dir/source.lock"
grep -Fq 'cpulimit=tdvp-cpulimit' "$package_dir/build.sh"
! grep -Eq '/usr/(s)?bin/cpulimit|apt|dpkg|debian' "$package_dir/build.sh"
grep -Fq 'cpu-limit-tools)' "$workflow"
grep -Fq 'package_args=(--package cpulimit)' "$workflow"
grep -Fq 'bash ./tests/cpulimit-package-policy.sh' "$workflow"
echo 'locked private cpulimit policy: PASS'
