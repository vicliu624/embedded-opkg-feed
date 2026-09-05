#!/usr/bin/env bash
# A dependent metadata batch may reuse only an entire successful merged
# candidate. It must not silently rebuild its already-admitted source closure
# or accept a loose local directory as package input.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

grep -Fq 'base_merged_run_id:' "$workflow"
grep -Fq "inputs.base_merged_run_id != ''" "$workflow"
grep -Fq 'Hydrate a verified prior merged candidate when requested' "$workflow"
grep -Fq 'base_merged_run_id must be one successful GitHub Actions run ID' "$workflow"
grep -Fq 'actions/runs/$TDVP_BASE_MERGED_RUN_ID' "$workflow"
grep -Fq '^tdvp-k230-r10-merged-unsigned-' "$workflow"
grep -Fq 'prior merged feed must not contain top-level symlinks' "$workflow"
grep -Fq 'prior merged artifact disagrees with immutable target runtime' "$workflow"
grep -Fq 'cmp -s "$source_ipk" "$destination_ipk"' "$workflow"
grep -Fq 'requires_prior_merged_candidate=1' "$workflow"
grep -Fq 'package_args=(--package tdvp-diagnostics)' "$workflow"
grep -Fq 'this batch requires a successful base_merged_run_id' "$workflow"

echo 'incremental merged-candidate hydration policy: PASS'
