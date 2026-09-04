#!/usr/bin/env bash
# Popt is a reusable public ABI and must remain separate from rsync.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/libpopt"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing libpopt policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libpopt'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]19-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line '^PACKAGE_DEPENDS='"''"'$' "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"
expect_line "BR2_PACKAGE_POPT popt 'libpopt[.]so[.]0\*'" "$package_dir/build.sh"
expect_line '--disable BR2_PACKAGE_LIBICONV' "$package_dir/build.sh"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='popt'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='1[.]19'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='popt-1[.]19[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line 'explicitly disables BR2_PACKAGE_LIBICONV' "$package_dir/source.lock"

grep -Fqx 'libpopt.so.0|libpopt|1.19-1' \
  <(sed 's/\r$//' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv")
expect_line 'archive-library --disable requires one BR2_\* symbol' \
  "$repo_root/support/buildroot-archive-library.sh"

echo 'source-built libpopt shared-runtime policy: PASS'
