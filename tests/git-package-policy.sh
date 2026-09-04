#!/usr/bin/env bash
# Keep Git as a locked-source, client-only split. The runtime package supplies
# private helpers/templates, while the public frontend remains a small leaf.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing Git policy entry in $path: $pattern" >&2
    exit 1
  }
}

for package in git git-runtime; do
  package_dir="$repo_root/packages/$package"
  expect_line "^PACKAGE='$package'$" "$package_dir/package.env"
  expect_line "^VERSION='2[.]48[.]1-1'$" "$package_dir/package.env"
  expect_line "^PACKAGE_RELEASES='r10'$" "$package_dir/package.env"
  expect_line "^SOURCE_REVISION='2[.]48[.]1'$" "$package_dir/package.env"
  expect_line "^SOURCE_ARCHIVE_SHA256='1c5d545f5dc1eb51e95d2c50d98fdf88b1a36ba1fa30e9ae5d5385c6024f82ad'$" "$package_dir/package.env"
  test -f "$package_dir/source.lock"
  expect_line "^UPSTREAM_NAME='Git'$" "$package_dir/source.lock"
  expect_line "^UPSTREAM_VERSION='2[.]48[.]1'$" "$package_dir/source.lock"
  expect_line "^SOURCE_ARTIFACT_1_FILE='git-2[.]48[.]1[.]tar[.]xz'$" "$package_dir/source.lock"
done

expect_line "^PACKAGE_KIND='runtime'$" "$repo_root/packages/git-runtime/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libz libssl-3 libcrypto-3 libcurl-4 libexpat-1 libpcre2-8'$" \
  "$repo_root/packages/git-runtime/package.env"
expect_line "^PACKAGE_DEPENDS='ca-certificates \\(= 2025[.]02[.]1-1\\)'$" \
  "$repo_root/packages/git-runtime/package.env"
expect_line "^PACKAGE_KIND='application'$" "$repo_root/packages/git/package.env"
expect_line "^PACKAGE_DEPENDS='git-runtime \\(= 2[.]48[.]1-1\\), ca-certificates \\(= 2025[.]02[.]1-1\\), openssh-client \\(= 9[.]9p2-1\\)'$" \
  "$repo_root/packages/git/package.env"

runtime_build="$repo_root/packages/git-runtime/build.sh"
expect_line 'TDVP_SOURCE_CACHE_ROOT' "$runtime_build"
expect_line 'GIT_VERSION = 2[.]48[.]1' "$runtime_build"
expect_line 'NO_GETTEXT=YesPlease NO_PERL=YesPlease NO_PYTHON=YesPlease' "$runtime_build"
expect_line 'NO_TCLTK=YesPlease NO_GITWEB=YesPlease' "$runtime_build"
expect_line 'INSTALL_SYMLINKS=YesPlease' "$runtime_build"
expect_line 'TEST_PROGRAMS= test_bindir_programs= UNIT_TEST_PROGS= CLAR_TEST_PROG=' "$runtime_build"
expect_line 'runtime_entries=' "$runtime_build"
expect_line 'git-remote-http git-remote-https' "$runtime_build"
expect_line 'Git runtime frontend link must resolve through the separate git leaf package' "$runtime_build"
expect_line 'daemon, CGI, shell-login' "$runtime_build"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$runtime_build"
if grep -Fq 'tdvp_buildroot_install' "$runtime_build"; then
  echo 'Git runtime must not invoke the desktop Buildroot package graph' >&2
  exit 1
fi

leaf_build="$repo_root/packages/git/build.sh"
expect_line 'git requires git-runtime to stage its locked source-built /usr/bin/git first' "$leaf_build"
expect_line 'tdvp_remove_elf_runtime_search_paths' "$leaf_build"
if grep -Eq 'cp .*usr/lib/' "$leaf_build"; then
  echo 'Git frontend must not embed a dynamic runtime library' >&2
  exit 1
fi

echo 'locked-source client-only Git split policy: PASS'
