#!/usr/bin/env bash
# Exercise the text-only cache refresh path.  It does not invoke Buildroot,
# compile K230 code, create an IPK, or consume an SDK cache.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
refresh="$repo_root/scripts/refresh-extra-runtime-owners.sh"
bash -n "$refresh"

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
grep -Fqx 'libyaml-0.so.2|libyaml-0|0.2.5-1' "$feed_dir/.tdvp-runtime-owners.tsv"
LC_ALL=C sort -cu "$feed_dir/.tdvp-runtime-owners.tsv"
grep -Eq '^refreshed [1-9][0-9]* source-built runtime owner records for r10$' "$fixture/first.log"

bash "$refresh" --platform tdvp-k230-r1 --release r10 --feed-dir "$feed_dir" >"$fixture/second.log"
grep -Fqx 'refreshed 0 source-built runtime owner records for r10' "$fixture/second.log"

printf '%s\n' 'libyaml-0.so.2|wrong-owner|0.2.5-1' >"$feed_dir/.tdvp-runtime-owners.tsv"
if bash "$refresh" --platform tdvp-k230-r1 --release r10 --feed-dir "$feed_dir" >"$fixture/conflict.log" 2>&1; then
  echo 'conflicting source owner unexpectedly accepted' >&2
  exit 1
fi
grep -Fq 'runtime owner conflict for libyaml-0.so.2' "$fixture/conflict.log"

echo 'source-built runtime-owner cache refresh policy: PASS'
