#!/usr/bin/env bash
# Validate actual generated payloads against the reviewed provider map.
# Run after source builds; this gate does not claim dependency closure.
set -Eeuo pipefail
[[ $# -eq 1 ]] || exit 64
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
readelf_tool="$1/bin/riscv64-unknown-linux-gnu-readelf"
owner_map="$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
[[ -x "$readelf_tool" ]] || exit 65
count=0
for package_dir in "$repo_root/packages/"*; do
  [[ -f "$package_dir/package.env" && -L "$package_dir/root" && -d "$package_dir/root/usr/lib" ]] || continue
  source "$package_dir/package.env"
  while IFS= read -r -d '' library; do
    soname=$("$readelf_tool" -d "$library" 2>/dev/null | sed -n 's/.*Library soname: \[\(.*\)\].*/\1/p')
    [[ -n "$soname" ]] || continue
    sed 's/\r$//' "$owner_map" | grep -Fx "$soname|$PACKAGE|$VERSION" >/dev/null || {
      echo "unregistered built runtime: $soname|$PACKAGE|$VERSION" >&2
      exit 1
    }
    count=$((count + 1))
  done < <(find "$package_dir/root/usr/lib" -maxdepth 1 -type f -name 'lib*.so*' -print0)
done
[[ $count -gt 0 ]] || { echo 'no built shared libraries inspected' >&2; exit 1; }
echo "built runtime owner coverage: PASS ($count ELF objects)"
