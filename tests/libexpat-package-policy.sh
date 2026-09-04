#!/usr/bin/env bash
# Keep Git's XML parser provider source-built and separately owned.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libexpat-1"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing Expat policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libexpat-1'$" "$package_dir/package.env"
expect_line "^VERSION='2[.]7[.]0-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='Expat'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='2[.]7[.]0'$" "$package_dir/source.lock"
expect_line "BR2_PACKAGE_EXPAT expat 'libexpat[.]so[*]' 'EXPAT_VERSION = 2[.]7[.]0'" "$package_dir/build.sh"
expect_line '^libexpat[.]so[.]1[|]libexpat-1[|]2[.]7[.]0-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
expect_line 'refusing to replace non-generated payload path' \
  "$repo_root/support/buildroot-archive-library.sh"

echo 'source-built Expat shared-runtime provider policy: PASS'
