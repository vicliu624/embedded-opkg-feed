#!/usr/bin/env bash
# Exercise the text-only cache refresh path.  It does not invoke Buildroot,
# compile K230 code, create an IPK, or consume an SDK cache.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
refresh="$repo_root/scripts/refresh-extra-runtime-owners.sh"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
bash -n "$refresh"
grep -Fq "platforms/tdvp-k230-r1/extra-runtime-owners.tsv" "$workflow"
grep -Fq 'source-runtime-owners.tsv registry is deliberately excluded' "$workflow"
if grep -E 'key:.*source-runtime-owners[.]tsv' "$workflow"; then
  echo 'candidate-only source runtime registry must not invalidate runtime-base cache' >&2
  exit 1
fi

fixture=$(mktemp -d)
cleanup() { rm -rf -- "$fixture"; }
trap cleanup EXIT
feed_dir="$fixture/riscv64"
mkdir -p "$feed_dir"
printf '%s\n' 'libfixture.so.1|fixture-runtime|1.0-1' >"$feed_dir/.tdvp-runtime-owners.tsv"

# This is deliberately only a temporary TSV fixture; the helper reads the
# committed package metadata and updates the private map in this temp dir.
bash "$refresh" --platform tdvp-k230-r1 --release r10 --feed-dir "$feed_dir" >"$fixture/first.log"
grep -Fqx 'libfixture.so.1|fixture-runtime|1.0-1' "$feed_dir/.tdvp-runtime-owners.tsv"
grep -Fqx 'libbz2.so.1.0|libbz2|1.0.8-1' "$feed_dir/.tdvp-runtime-owners.tsv"
LC_ALL=C sort -cu "$feed_dir/.tdvp-runtime-owners.tsv"
grep -Eq '^refreshed [1-9][0-9]* source-built runtime owner records for r10$' "$fixture/first.log"

bash "$refresh" --platform tdvp-k230-r1 --release r10 --feed-dir "$feed_dir" >"$fixture/second.log"
grep -Fqx 'refreshed 0 source-built runtime owner records for r10' "$fixture/second.log"

printf '%s\n' 'libbz2.so.1.0|wrong-owner|1.0.8-1' >"$feed_dir/.tdvp-runtime-owners.tsv"
if bash "$refresh" --platform tdvp-k230-r1 --release r10 --feed-dir "$feed_dir" >"$fixture/conflict.log" 2>&1; then
  echo 'conflicting source owner unexpectedly accepted' >&2
  exit 1
fi
grep -Fq 'runtime owner conflict for libbz2.so.1.0' "$fixture/conflict.log"

echo 'source-built runtime-owner cache refresh policy: PASS'
