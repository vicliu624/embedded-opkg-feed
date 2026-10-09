#!/usr/bin/env bash
# Run the same pre-compilation gates in portable CI and every source batch.
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for script in "$repo_root"/scripts/*.sh "$repo_root"/tests/*.sh "$repo_root"/packages/*/build.sh; do
  bash -n "$script"
done
for policy in build-all-source-lock-policy audacious-foundation-policy audacious-package-policy archive-package-policy target-runtime-provider-deferral-policy feed-overlay-composition-policy source-lock-policy; do
  printf 'Batch preflight: %s\n' "$policy"
  bash "$repo_root/tests/$policy.sh"
done
bash "$repo_root/scripts/verify-source-lock.sh" --repo-root "$repo_root" --all
echo 'Shared batch preflight: PASS'
