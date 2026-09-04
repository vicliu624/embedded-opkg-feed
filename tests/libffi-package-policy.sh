#!/usr/bin/env bash
# Keep the public FFI ABI source-built and independently owned before Python.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libffi-8"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing libffi policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libffi-8'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]4[.]6-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='libffi'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='3[.]4[.]6'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='libffi-3[.]4[.]6[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "BR2_PACKAGE_LIBFFI libffi 'libffi[.]so[*]' 'LIBFFI_VERSION = 3[.]4[.]6'" \
  "$package_dir/build.sh"
expect_line '^libffi[.]so[.]8[|]libffi-8[|]3[.]4[.]6-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

echo 'source-built libffi shared-runtime policy: PASS'
