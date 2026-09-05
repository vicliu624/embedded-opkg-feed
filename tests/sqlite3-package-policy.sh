#!/usr/bin/env bash
# Keep the SQLite CLI as a staged source-built leaf, never as a firmware copy
# or a second shared-library provider.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
library_dir="$repo_root/packages/libsqlite3-0"
package_dir="$repo_root/packages/sqlite3"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing SQLite CLI policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='sqlite3'$" "$package_dir/package.env"
expect_line "^VERSION='3[.]48[.]0-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libsqlite3-0 \\(= 3[.]48[.]0-1\\), libreadline \\(= 8[.]2-1\\), libncursesw \\(= 6[.]4-20230603-1\\)'$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS='libsqlite3-0 libreadline libncursesw'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
if grep -Eq '^PACKAGE_STAGE_BUILD_DEPENDS=' "$package_dir/package.env"; then
  echo 'sqlite3 must use normal source build ordering, not a deferred target-runtime staging dependency' >&2
  exit 1
fi
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='SQLite'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='sqlite-autoconf-3480000[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "SOURCE_ARTIFACT_1_SHA256='ac992f7fca3989de7ed1fe99c16363f848794c8c32a158dafd4eb927a2e02fd5'" "$package_dir/source.lock"
expect_line "--stage-command /usr/bin/sqlite3" "$library_dir/build.sh"
expect_line "sqlite3 requires libsqlite3-0 to stage its locked source-built /usr/bin/sqlite3 first" "$package_dir/build.sh"
expect_line "source-package=libsqlite3-0" "$package_dir/build.sh"
expect_line "buildroot-package=sqlite" "$package_dir/build.sh"
expect_line "Shared library: \\[libsqlite3[.]so[.]0\\]" "$package_dir/build.sh"
grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, nodejs]' "$workflow"
grep -Fq 'database-tools)' "$workflow"
grep -Fq 'package_args=(--package sqlite3)' "$workflow"
grep -Fq 'expected_packages=(libsqlite3-0 sqlite3)' "$workflow"
grep -Fq 'bash ./tests/sqlite3-package-policy.sh' "$workflow"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$package_dir/build.sh"; then
  echo 'sqlite3 build must not import a Debian package or binary' >&2
  exit 1
fi

echo 'staged SQLite CLI policy: PASS'
