#!/usr/bin/env bash
# The cohort fetch helper has no build path. Its offline failure must be a
# source-cache miss, never an attempted download or an IPK side effect.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/scripts/fetch-r10-candidate-cohort.sh"
cohort="$repo_root/support/r10-candidate-cohort.sh"
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

bash -n "$script"
bash -n "$cohort"
grep -Fq 'TDVP_R10_CANDIDATE_COHORT' "$script"
grep -Fq 'generate an IPK, sign, install, or publish anything' "$script"
grep -Fq -- '--ca-bundle' "$script"

if bash "$script" --offline --cache "$work_root/cache" >"$work_root/result.log" 2>&1; then
  echo 'r10 cohort source fetch unexpectedly passed with an empty offline cache' >&2
  exit 1
fi
grep -Fq 'offline source cache miss: popt-1.19.tar.gz' "$work_root/result.log"

echo 'r10 candidate cohort fetch policy: PASS'
