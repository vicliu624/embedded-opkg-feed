#!/usr/bin/env bash
# Keep the OpenSSL SONAME split, shared source provenance, and offline input
# boundary explicit before transport applications may use TLS.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing OpenSSL policy entry in $path: $pattern" >&2
    exit 1
  }
}

for package in libcrypto-3 libssl-3; do
  package_dir="$repo_root/packages/$package"
  expect_line "^PACKAGE='$package'$" "$package_dir/package.env"
  expect_line "^VERSION='3[.]4[.]1-1'$" "$package_dir/package.env"
  expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
  expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
  test -f "$package_dir/source.lock"
  expect_line "^UPSTREAM_NAME='OpenSSL'$" "$package_dir/source.lock"
  expect_line "^UPSTREAM_VERSION='3[.]4[.]1'$" "$package_dir/source.lock"
  expect_line "^SOURCE_ARTIFACT_2_FILE='zlib-1[.]3[.]1[.]tar[.]xz'$" "$package_dir/source.lock"
  case "$package" in
    libcrypto-3) expected_library='libcrypto[.]so[*]' ;;
    libssl-3) expected_library='libssl[.]so[*]' ;;
  esac
  expect_line "BR2_PACKAGE_LIBOPENSSL libopenssl '$expected_library'" "$package_dir/build.sh"
done

expect_line "^PACKAGE_DEPENDS='libcrypto-3 \\(= 3[.]4[.]1-1\\)'$" \
  "$repo_root/packages/libssl-3/package.env"
expect_line '^libcrypto[.]so[.]3[|]libcrypto-3[|]3[.]4[.]1-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"
expect_line '^libssl[.]so[.]3[|]libssl-3[|]3[.]4[.]1-1$' \
  "$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

echo 'source-built OpenSSL shared-runtime split policy: PASS'
