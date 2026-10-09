#!/usr/bin/env bash
# Pre-package gate: every actual DT_NEEDED must have a reviewed provider.
# The IPK closure gate additionally verifies that control Depends declares it.
set -Eeuo pipefail
[[ $# -eq 2 ]] || exit 64
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readelf_tool="$1/bin/riscv64-unknown-linux-gnu-readelf"
catalogue_owners=$2
[[ -x "$readelf_tool" && -s "$catalogue_owners" ]] || exit 65
declare -A owners=()
for map in "$catalogue_owners" "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"; do
  while IFS='|' read -r soname package version; do
    [[ -n "$soname" && "$soname" != \#* ]] || continue
    owners[$soname]=$package
  done < "$map"
done
while IFS='|' read -r package version description sonames; do
  [[ -n "$package" && "$package" != \#* ]] || continue
  sonames=${sonames%$'\r'}
  IFS=',' read -r -a names <<< "$sonames"
  for soname in "${names[@]}"; do owners[$soname]=$package; done
done < "$repo_root/platforms/tdvp-k230-r1/seed-packages.tsv"
checked=0
missing=0
for package_dir in "$repo_root/packages/"*; do
  [[ -f "$package_dir/package.env" && -L "$package_dir/root" ]] || continue
  # Package-local helper libraries are owned by this payload. Their loading
  # mechanism is checked separately by final-payload import/runtime tests.
  declare -A package_sonames=()
  while IFS= read -r -d '' object; do
    while IFS= read -r soname; do
      [[ -z "$soname" ]] || package_sonames[$soname]=1
    done < <("$readelf_tool" -d "$object" 2>/dev/null | sed -n 's/.*(SONAME).*\[\(.*\)\].*/\1/p')
  done < <(find -L "$package_dir/root" -type f -name '*.so*' -print0)
  while IFS= read -r -d '' object; do
    [[ $(head -c 4 "$object") == $'\177ELF' ]] || continue
    while IFS= read -r needed; do
      [[ -n "$needed" ]] || continue
      if [[ -z ${owners[$needed]:-} && -z ${package_sonames[$needed]:-} ]]; then
        echo "missing dependency provider: ${package_dir##*/}: $needed ($object)" >&2
        missing=$((missing + 1))
      fi
      checked=$((checked + 1))
    done < <("$readelf_tool" -d "$object" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\].*/\1/p')
  done < <(find -L "$package_dir/root" -type f \( -name '*.so*' -o -perm -u+x \) -print0)
done
[[ $missing -eq 0 && $checked -gt 0 ]] || exit 1
echo "built runtime dependency providers: PASS ($checked DT_NEEDED records)"
