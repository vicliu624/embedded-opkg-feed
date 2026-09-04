#!/usr/bin/env bash
# Static contract for the incremental retro-gba cohort.  The actual K230
# compilation and ELF/closure gates run only in GitHub Actions.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

for package in sdl2 sdl2-ttf libmgba tdvp-gba; do
  package_dir="$repo_root/packages/$package"
  test -f "$package_dir/package.env"
  test -f "$package_dir/build.sh"
  test -f "$package_dir/source.lock"
  bash "$repo_root/scripts/verify-source-lock.sh" --package-dir "$package_dir" >/dev/null
  grep -Fq 'tdvp_unpack_locked_source_archive' "$package_dir/build.sh"
done

locked_revision=$(sed -n -E "s/^UPSTREAM_REVISION='([^']+)'$/\1/p" \
  "$repo_root/packages/tdvp-gba/source.lock")
[[ "$locked_revision" =~ ^[0-9a-f]{40}$ ]]
grep -Fqx "SOURCE_REVISION='$locked_revision'" "$repo_root/packages/tdvp-gba/package.env"
if grep -Fq 'not downloadable from its public GitHub archive endpoint' \
  "$repo_root/packages/tdvp-gba/source.lock"; then
  echo 'tdvp-gba source lock still claims the verified public archive is unavailable' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, nodejs]' "$workflow"
grep -Fq 'retro-gba)' "$workflow"
grep -Fq 'package_args=(--package sdl2-ttf --package tdvp-gba)' "$workflow"
grep -Fq 'expected_packages=(sdl2 sdl2-ttf libmgba tdvp-gba)' "$workflow"
grep -Fq 'if [ "${{ inputs.batch }}" = retro-gba ]; then' "$workflow"
grep -Fq 'export TDVP_REUSE_PUBLISHED_PAYLOADS=0' "$workflow"
grep -Fq 'bash ./tests/retro-gba-package-policy.sh' "$workflow"

echo 'retro-gba package policy test passed'
