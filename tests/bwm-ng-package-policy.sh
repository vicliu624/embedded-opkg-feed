#!/usr/bin/env bash
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/bwm-ng"; workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
grep -Fqx "PACKAGE='bwm-ng'" "$package_dir/package.env"
grep -Fqx "PACKAGE_DEPENDS=''" "$package_dir/package.env"
grep -Fqx "SOURCE_ARTIFACT_1_SHA256='c1a552b6ff48ea3e4e10110a7c188861abc4750befc67c6caaba8eb3ecf67f46'" "$package_dir/source.lock"
grep -Fq 'bwm-ng=tdvp-bwm-ng' "$package_dir/build.sh"
grep -Fq "TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_NCURSES'" "$package_dir/build.sh"
grep -Fq 'bandwidth-monitor-tools)' "$workflow"
grep -Fq 'package_args=(--package bwm-ng)' "$workflow"
grep -Fq 'bash ./tests/bwm-ng-package-policy.sh' "$workflow"
echo 'locked private bwm-ng policy: PASS'
