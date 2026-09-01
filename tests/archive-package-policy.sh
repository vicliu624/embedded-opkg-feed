#!/usr/bin/env bash
# Fast source-level assertions for the r9 archive split.  The candidate job
# later verifies the actual ELF closure and IPK ownership against the K230
# target, but these checks catch accidental library bundling before a long run.
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

for package in libbz2 liblzma libzstd archive-tools; do
  test -f "$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE='$package'" "$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE_RELEASES='r9 r10'" "$repo_root/packages/$package/package.env"
done
grep -Fqx 'libbz2.so.1.0|libbz2|1.0.8-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fqx 'liblzma.so.5|liblzma|5.6.4-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fqx 'libzstd.so.1|libzstd|1.5.7-1' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
grep -Fq 'PACKAGE_DEPENDS='"'"'libbz2 (= 1.0.8-1), liblzma (= 5.6.4-1), libzstd (= 1.5.7-1)'"'"'' "$repo_root/packages/archive-tools/package.env"
grep -Fq '/usr/libexec/tdvp-archive' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'for command in tar gzip gunzip zcat bzip2 bunzip2 bzcat xz unxz xzcat zstd unzstd zstdcat zip unzip 7za' "$repo_root/packages/archive-tools/build.sh"
if grep -Eq 'cp .*usr/lib' "$repo_root/packages/archive-tools/build.sh"; then
  echo 'archive-tools must not copy a private archive library' >&2
  exit 1
fi
