#!/usr/bin/env bash
# Run the same pre-compilation gates in portable CI and every source batch.
set -Eeuo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 "$repo_root/tests/extra-runtime-owner-version-policy.py"
python3 "$repo_root/tests/node-provider-version-policy.py"
python3 "$repo_root/tests/source-recipe-exact-dependencies.py"
python3 "$repo_root/tests/icu-native-source-layout.py"
bash "$repo_root/tests/dev-tools-package-policy.sh"
bash "$repo_root/tests/published-sdk-lzip-policy.sh"
python3 "$repo_root/tests/command-staging-export-integration.py"
python3 "$repo_root/tests/go-package-notices.py"
bash "$repo_root/tests/common-tool-notice-policy.sh"
python3 "$repo_root/tests/notice-projection-lifetime.py"
bash "$repo_root/tests/vim-plugin-notice-policy.sh"
for script in "$repo_root"/scripts/*.sh "$repo_root"/tests/*.sh "$repo_root"/packages/*/build.sh; do
  bash -n "$script"
done
for policy in build-all-source-lock-policy audacious-foundation-policy audacious-package-policy archive-package-policy target-runtime-provider-deferral-policy feed-overlay-composition-policy source-lock-policy; do
  printf 'Batch preflight: %s\n' "$policy"
  bash "$repo_root/tests/$policy.sh"
done
bash "$repo_root/scripts/verify-source-lock.sh" --repo-root "$repo_root" --all
echo 'Shared batch preflight: PASS'
