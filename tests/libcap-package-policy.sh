#!/usr/bin/env bash
# Keep libcap as one explicit source-built runtime owner before htop uses it.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libcap-2"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing libcap runtime policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libcap-2'$" "$package_dir/package.env"
expect_line "^VERSION='2[.]73-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line '^PACKAGE_DEPENDS='"''"'$' "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"
expect_line "BR2_PACKAGE_LIBCAP libcap 'libcap[.]so[.]2\*' 'LIBCAP_VERSION = 2[.]73'" "$package_dir/build.sh"
expect_line '--disable BR2_PACKAGE_LIBCAP_TOOLS' "$package_dir/build.sh"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='libcap'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='2[.]73'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='libcap-2[.]73[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line 'host-gperf is a reviewed baseline host helper' "$package_dir/source.lock"
grep -Fqx 'libcap.so.2|libcap-2|2.73-1' \
  <(sed 's/\r$//' "$repo_root/platforms/tdvp-k230-r1/source-runtime-owners.tsv")

echo 'source-built libcap shared-runtime policy: PASS'
