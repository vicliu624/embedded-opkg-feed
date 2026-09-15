#!/usr/bin/env bash
# Keep the toolchain-runtime exception narrow: it must transfer the exact
# matched-target object rather than admitting an arbitrary RISC-V binary.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libatomic-1"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing libatomic runtime-policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libatomic-1'$" "$package_dir/package.env"
expect_line "^VERSION='14[.]1[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='runtime'$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='identical'$" "$package_dir/package.env"
expect_line "^SOURCE_LOCK_EXEMPT_REASON='Target-derived compiler runtime transfer:" "$package_dir/package.env"
expect_line "^RUNTIME_LIBRARY_SHA256='[0-9a-f]{64}'$" "$package_dir/package.env"
expect_line 'BR2_TOOLCHAIN_HAS_LIBATOMIC=y' "$package_dir/build.sh"
expect_line 'tdvp_assert_elf_without_runtime_search_path' "$package_dir/build.sh"
expect_line 'refusing to replace non-generated payload path' "$package_dir/build.sh"
expect_line '^libatomic[.]so[.]1[|]libatomic-1[|]14[.]1[.]1-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

echo 'matched-target libatomic runtime-transfer policy: PASS'
