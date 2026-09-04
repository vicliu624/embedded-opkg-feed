#!/usr/bin/env bash
# Static contract for the GitHub-only artifact merge path.  It must not
# compile packages, fetch source archives, create IPKs, or use a gh CLI field
# that is unavailable on the hosted runner's bundled version.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fq 'name: Merge verified r10 batches without recompiling' "$workflow"
grep -Fq 'name: Download compatible unsigned batches and compare every IPK hash' "$workflow"
grep -Fq 'gh api --paginate' "$workflow"
grep -Fq 'repos/$GITHUB_REPOSITORY/actions/runs/$run_id/artifacts?per_page=100' "$workflow"
grep -Fq -- "--jq '.artifacts[].name | select(test(\"^tdvp-k230-r10-.*-unsigned-\"))'" "$workflow"
grep -Fq 'gh run download "$run_id" --repo "$GITHUB_REPOSITORY"' "$workflow"
grep -Fq 'Re-index and validate the merged candidate without compiling' "$workflow"
if grep -Fq 'gh run view "$run_id" --repo "$GITHUB_REPOSITORY" --json artifacts' "$workflow"; then
  echo 'merge workflow uses an unavailable gh run view artifacts field' >&2
  exit 1
fi

echo 'merge-batches policy test passed'
