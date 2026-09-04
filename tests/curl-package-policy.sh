#!/usr/bin/env bash
# Keep curl as a narrow leaf of libcurl-4's one locked Buildroot transaction.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/curl"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing curl policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='curl'$" "$package_dir/package.env"
expect_line "^VERSION='8[.]12[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libcurl-4 \\(= 8[.]12[.]1-1\\), ca-certificates \\(= 2025[.]02[.]1-1\\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libcurl-4'$" "$package_dir/package.env"
expect_line '^PACKAGE_AUTO_RUNTIME_DEPENDS=1$' "$package_dir/package.env"

test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='curl'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='8[.]12[.]1'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='curl-8[.]12[.]1[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line 'immediately preceding locked Buildroot source build' "$package_dir/source.lock"
cmp -s \
  <(grep -E '^SOURCE_ARTIFACT_[0-9]+_(URL|FILE|SHA256)=' "$package_dir/source.lock") \
  <(grep -E '^SOURCE_ARTIFACT_[0-9]+_(URL|FILE|SHA256)=' "$repo_root/packages/libcurl-4/source.lock") || {
  echo 'curl leaf must repeat the exact libcurl-4 Buildroot source closure' >&2
  exit 1
}

build_file="$package_dir/build.sh"
expect_line 'curl requires libcurl-4 to stage its locked source-built /usr/bin/curl first' "$build_file"
expect_line 'libcurl-4 Buildroot staging proof' "$build_file"
expect_line 'Machine:                           RISC-V' "$build_file"
expect_line 'Shared library: \[libcurl[.]so[.]4\]' "$build_file"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$build_file"
expect_line 'tdvp_assert_elf_without_runtime_search_path' "$build_file"
expect_line 'install -Dm 0755 -- "\$stage_command" "\$payload_dir/usr/bin/curl"' "$build_file"
if grep -Eq 'curl.*(https?://|apt|dpkg|debian)' "$build_file"; then
  echo 'curl leaf must not fetch or import a foreign binary during target packaging' >&2
  exit 1
fi

helper="$repo_root/support/buildroot-archive-library.sh"
expect_line '^      --stage-command\)$' "$helper"
expect_line 'staged Buildroot command requires TDVP_FEED_STAGING_ROOT from build-all.sh' "$helper"
expect_line 'buildroot-package=\$buildroot_package' "$helper"

echo 'locked-source curl/libcurl split policy: PASS'
