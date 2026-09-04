#!/usr/bin/env bash
# Keep target-owned SONAMEs as byte-identical catalogue providers.  A matching
# source recipe is deferred only with an explicit package/version attestation.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
catalogue="$repo_root/scripts/build-runtime-catalog.sh"
build_all="$repo_root/scripts/build-all.sh"
runtime_closure="$repo_root/scripts/verify-runtime-closure.sh"

grep -Fq 'target_provider_manifest="$output_dir/.tdvp-target-runtime-packages.tsv"' "$catalogue"
grep -Fq 'target provider package collides with an un-attested target SONAME:' "$catalogue"
grep -Fq 'target_provider_version[$soname]=$version' "$catalogue"
grep -Fq 'target_package_sonames[$package]+="$soname"' "$catalogue"
grep -Fq 'register_runtime_needed_owner()' "$catalogue"
grep -Fq 'filename=${source##*/}' "$catalogue"
grep -Fq '/usr/libexec/vicliu-pocket-linux-hardware/vpl-hardwared' "$repo_root/platforms/tdvp-k230-r1/runtime-data-packages.tsv"
grep -Fq 'build_generated_package "$package" "$description" "$root" "$runtime_version"' "$catalogue"
grep -Fq 'target_runtime_provider_manifest="$feed_dir/.tdvp-target-runtime-packages.tsv"' "$build_all"
grep -Fq 'source runtime recipe deferred; target owns' "$build_all"
grep -Fq 'target runtime provider version is not attested for' "$build_all"
grep -Fq '[[ -n "${target_runtime_provider[$dependency]:-}" ]] && continue' "$build_all"
grep -Fq '"$feed_dir/.tdvp-target-runtime-packages.tsv"' "$build_all"
grep -Fq 'empty dynamic-string value is represented by readelf as []' \
  "$repo_root/support/elf-runtime-policy.sh"
grep -Fq "grep -Ev '\\[[[:space:]]*\\]'" "$repo_root/support/elf-runtime-policy.sh"
grep -Fq 'assert_elf_runtime_search_path_policy()' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'retains a byte-identical target RPATH/RUNPATH' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'cmp -s -- "$elf" "$base_elf"' "$repo_root/scripts/build-ipk.sh"
grep -Fq 'top-level /usr/lib/lib*.so* provider with no DT_SONAME' "$runtime_closure"
grep -Fq 'runtime provider name $provider_name is supplied by both' "$runtime_closure"
grep -Fq 'find "$library_root" -maxdepth 1 -type f -name '\''lib*.so*'\'' -print' "$runtime_closure"

echo 'target runtime provider deferral policy: PASS'
