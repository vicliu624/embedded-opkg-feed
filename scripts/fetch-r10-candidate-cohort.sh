#!/usr/bin/env bash
# Prepare every r10 candidate source archive in the content-addressed cache.
# This is deliberately a controlled retrieval helper only: it does not call a
# package build, generate an IPK, sign, install, or publish anything.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  cat >&2 <<'EOF'
usage: fetch-r10-candidate-cohort.sh --cache <source-cache> [--offline] [--ca-bundle <pem-file>]
EOF
  exit 64
}

cache_root=
ca_bundle=
offline=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cache)
      [[ $# -ge 2 && -z "$cache_root" ]] || usage
      cache_root=$2
      shift 2
      ;;
    --offline)
      offline=1
      shift
      ;;
    --ca-bundle)
      [[ $# -ge 2 && -z "$ca_bundle" ]] || usage
      ca_bundle=$2
      shift 2
      ;;
    *) usage ;;
  esac
done
[[ -n "$cache_root" ]] || usage

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../support/r10-candidate-cohort.sh
source "$repo_root/support/r10-candidate-cohort.sh"

for package in "${TDVP_R10_CANDIDATE_COHORT[@]}"; do
  package_dir="$repo_root/packages/$package"
  [[ -d "$package_dir" && -f "$package_dir/source.lock" ]] || {
    echo "r10 candidate package has no source lock: $package" >&2
    exit 65
  }
  fetch_args=(--cache "$cache_root" --package-dir "$package_dir")
  [[ "$offline" -eq 0 ]] || fetch_args+=(--offline)
  [[ -z "$ca_bundle" ]] || fetch_args+=(--ca-bundle "$ca_bundle")
  bash "$repo_root/scripts/fetch-source-cache.sh" "${fetch_args[@]}"
done

echo "r10 candidate source cache prepared: $cache_root"
