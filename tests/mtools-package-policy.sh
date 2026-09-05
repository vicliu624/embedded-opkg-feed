#!/usr/bin/env bash
# Keep GNU mtools inside an explicit TDVP namespace and retain its argv[0]
# multi-call semantics only in a private payload directory.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/mtools"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing mtools policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='mtools'$" "$package_dir/package.env"
expect_line "^VERSION='4[.]0[.]47-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='GNU mtools'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='4[.]0[.]47'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='mtools-4[.]0[.]47[.]tar[.]lz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='2709cd2f42d65500829b056cb0630edd515d7060b4865bad31277f0da9f9e9d5'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_FILE='lzip-1[.]25[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_SHA256='09418a6d8fb83f5113f5bd856e09703df5d37bae0308c668d0f346e3d3f0a56f'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'MTOOLS_VERSION = 4[.]0[.]47' "$build_file"
expect_line 'BR2_PACKAGE_MTOOLS' "$build_file"
expect_line 'tdvp_buildroot_command_package' "$build_file"
expect_line 'TDVP_COMMAND_FRONTEND_NAMES=' "$build_file"
for frontend in tdvp-mtools tdvp-mtools-mdir tdvp-mtools-mcopy tdvp-mtools-mformat tdvp-mtools-mlabel; do
  grep -Fq "$frontend" "$build_file"
done
for command in mtools mkmanifest mdir mcopy mformat mlabel; do
  grep -Fq "$command" "$build_file"
done
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'mtools build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, nodejs]' "$workflow"
grep -Fq 'fat-media-tools)' "$workflow"
grep -Fq 'package_args=(--package mtools)' "$workflow"
grep -Fq 'expected_packages=(mtools)' "$workflow"
grep -Fq 'bash ./tests/mtools-package-policy.sh' "$workflow"

echo 'isolated GNU mtools policy: PASS'
