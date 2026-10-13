#!/usr/bin/env bash
# Keep Git's HTTPS transport runtime minimal, source-built, and explicit.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/libcurl-4"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing libcurl policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libcurl-4'$" "$package_dir/package.env"
expect_line "^VERSION='8[.]12[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='ca-certificates \\(= 2025[.]02[.]1-1\\), libssl-3 \\(= 3[.]4[.]1-1\\), libcrypto-3 \\(= 3[.]4[.]1-1\\), libzstd \\(= 1[.]5[.]7-1\\), libz \\(= 1[.]3[.]1-1\\), libatomic-1 \\(= 14[.]1[.]1-1\\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_SDK_DEVELOPMENT_FILES='usr/include/curl/curl[.]h usr/lib/pkgconfig/libcurl[.]pc usr/lib/libcurl[.]so usr/bin/curl-config'$" "$package_dir/package.env"
expect_line '^PACKAGE_SOURCE_STAGING=0$' "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='curl'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='8[.]12[.]1'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_4_FILE='pkgconf-2[.]3[.]0[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line '^libcurl[.]so[.]4[|]libcurl-4[|]8[.]12[.]1-1$' "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

echo 'SDK-projected libcurl shared-runtime policy: PASS'
