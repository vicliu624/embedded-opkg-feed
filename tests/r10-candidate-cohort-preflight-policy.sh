#!/usr/bin/env bash
# A cohort gate must reject an incomplete SDK before it attempts a package
# build, reads a target archive, or can produce an IPK.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work_root=$(mktemp -d)
cleanup() { rm -rf -- "$work_root"; }
trap cleanup EXIT

mkdir -p "$work_root/incomplete-sdk" "$work_root/cache"
if bash "$repo_root/scripts/verify-r10-candidate-cohort.sh" \
  --sdk-root "$work_root/incomplete-sdk" --cache "$work_root/cache" \
  >"$work_root/result.log" 2>&1; then
  echo 'r10 candidate preflight accepted an incomplete SDK' >&2
  exit 1
fi
grep -Fq 'the feed recipe needs a completed matching Buildroot output directory' \
  "$work_root/result.log"

echo 'r10 candidate cohort incomplete-SDK policy: PASS'
