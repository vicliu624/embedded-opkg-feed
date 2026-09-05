#!/usr/bin/env bash
# Fast source-level assertions for the r9 archive split.  The candidate job
# later verifies the actual ELF closure and IPK ownership against the K230
# target, but these checks catch accidental library bundling before a long run.
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
owner_map=$(sed 's/\r$//' "$repo_root/platforms/tdvp-k230-r1/source-runtime-owners.tsv")

for package in libbz2 liblzma libzstd archive-tools; do
  test -f "$repo_root/packages/$package/package.env"
  test -f "$repo_root/packages/$package/source.lock"
  grep -Fqx "PACKAGE='$package'" "$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE_RELEASES='r9 r10'" "$repo_root/packages/$package/package.env"
done
grep -Fqx 'libbz2.so.1.0|libbz2|1.0.8-1' <<<"$owner_map"
grep -Fqx 'liblzma.so.5|liblzma|5.6.4-1' <<<"$owner_map"
grep -Fqx 'libzstd.so.1|libzstd|1.5.7-1' <<<"$owner_map"
grep -Fq 'PACKAGE_DEPENDS='"'"'libbz2 (= 1.0.8-1), liblzma (= 5.6.4-1), libzstd (= 1.5.7-1)'"'"'' "$repo_root/packages/archive-tools/package.env"
grep -Fq '/usr/libexec/tdvp-archive' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'tdvp_prepare_locked_buildroot_download' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'run_buildroot_install --offline-download-dir' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'tdvp_remove_elf_runtime_search_paths' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'tdvp-archive-$name' "$repo_root/packages/archive-tools/build.sh"
grep -Fq 'tdvp-command-payload.' "$repo_root/support/buildroot-archive-library.sh"
grep -Fq 'chmod 0755 -- "$payload_dir"' "$repo_root/support/buildroot-archive-library.sh"
grep -Fq 'source "$package_dir/../../support/elf-runtime-policy.sh"' "$repo_root/support/buildroot-archive-library.sh"
grep -Fq 'tdvp_remove_elf_runtime_search_paths "$readelf_tool" "$elf"' "$repo_root/support/buildroot-archive-library.sh"
grep -Fq 'for command in tar gzip gunzip zcat bzip2 bunzip2 bzcat xz unxz xzcat zstd unzstd zstdcat zip unzip 7za' "$repo_root/packages/archive-tools/build.sh"
if grep -Fq '"$payload_dir/usr/bin/$name"' "$repo_root/packages/archive-tools/build.sh"; then
  echo 'archive-tools must use collision-free frontend names' >&2
  exit 1
fi
if grep -Eq 'cp .*usr/lib' "$repo_root/packages/archive-tools/build.sh"; then
  echo 'archive-tools must not copy a private archive library' >&2
  exit 1
fi
