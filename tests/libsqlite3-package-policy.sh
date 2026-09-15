#!/usr/bin/env bash
# Keep SQLite as an independently owned public ABI before Python imports it.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libsqlite3-0"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing SQLite policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libsqlite3-0'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]48[.]0-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='SQLite'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='3[.]48[.]0'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='sqlite-autoconf-3480000[.]tar[.]gz'$" \
  "$package_dir/source.lock"
expect_line "BR2_PACKAGE_SQLITE sqlite 'libsqlite3[.]so[*]' 'SQLITE_VERSION = 3[.]48[.]0'" \
  "$package_dir/build.sh"
expect_line '^libsqlite3[.]so[.]0[|]libsqlite3-0[|]3[.]48[.]0-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

echo 'source-built SQLite shared-runtime policy: PASS'
