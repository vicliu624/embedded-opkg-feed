#!/usr/bin/env bash
# Keep glibc-owned resolver/utility SONAMEs in the immutable ABI seed rather
# than allowing an application to smuggle them into an upgradeable feed IPK.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
seed="$repo_root/platforms/tdvp-k230-r1/seed-packages.tsv"

grep -Fq 'libutil.so.1,libresolv.so.2' "$seed"
for path in "$repo_root/scripts/build-ipk.sh" "$repo_root/scripts/build-runtime-catalog.sh"; do
  grep -Fq 'libutil.so' "$path"
  grep -Fq 'libresolv.so' "$path"
done

echo 'glibc utility/resolver ABI seed policy: PASS'
