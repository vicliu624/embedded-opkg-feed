#!/usr/bin/env bash
# Keep source-built FAT filesystem tools private and collision-free.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/dosfstools"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing dosfstools policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='dosfstools'$" "$package_dir/package.env"
expect_line "^VERSION='4[.]2-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='dosfstools'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='4[.]2'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='dosfstools-4[.]2[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'DOSFSTOOLS_VERSION = 4[.]2' "$build_file"
for symbol in BR2_PACKAGE_DOSFSTOOLS BR2_PACKAGE_DOSFSTOOLS_FATLABEL BR2_PACKAGE_DOSFSTOOLS_FSCK_FAT BR2_PACKAGE_DOSFSTOOLS_MKFS_FAT; do
  grep -Fq "$symbol" "$build_file"
done
for command in fatlabel fsck.fat mkfs.fat; do
  grep -Fq "$command" "$build_file"
done
grep -Fq '"$target_root/sbin"' "$repo_root/support/buildroot-feed-session.sh"
for frontend in tdvp-dosfstools-fatlabel tdvp-dosfstools-fsck-fat tdvp-dosfstools-mkfs-fat; do
  grep -Fq "$frontend" "$build_file"
done
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'dosfstools build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, system-tools, nodejs]' "$workflow"
grep -Fq 'fat-filesystem-tools)' "$workflow"
grep -Fq 'package_args=(--package dosfstools)' "$workflow"
grep -Fq 'expected_packages=(dosfstools)' "$workflow"
grep -Fq 'bash ./tests/dosfstools-package-policy.sh' "$workflow"

echo 'isolated dosfstools policy: PASS'
