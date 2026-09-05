#!/usr/bin/env bash
# Admission policy for the private GNU findutils command leaf. This test is
# static: it must not call find/xargs, inspect a target filesystem, or start a
# target command.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/findutils"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fqx "PACKAGE='findutils'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5'" "$package_dir/source.lock"
grep -Fq "FINDUTILS_VERSION = 4.10.0" "$package_dir/build.sh"
grep -Fq "TDVP_COMMAND_FRONTEND_NAMES='find=tdvp-find xargs=tdvp-xargs'" "$package_dir/build.sh"
grep -Fq "filesystem-search-tools)" "$workflow"
grep -Fq "package_args=(--package findutils)" "$workflow"
grep -Fq 'bash ./tests/findutils-package-policy.sh' "$workflow"
echo 'locked private findutils policy: PASS'
