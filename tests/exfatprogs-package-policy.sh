#!/usr/bin/env bash
# Keep source-built exFAT filesystem tools private and collision-free.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/exfatprogs"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing exfatprogs policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='exfatprogs'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]2[.]5-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='exfatprogs'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='1[.]2[.]5'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='exfatprogs-1[.]2[.]5[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='f27160dcc1ddd17c96cd41a6ceef7037adc2796ab5c5633d3d85cf532c3ee2f0'$" "$package_dir/source.lock"

build_file="$package_dir/build.sh"
expect_line 'EXFATPROGS_VERSION = 1[.]2[.]5' "$build_file"
grep -Fq 'BR2_PACKAGE_EXFATPROGS' "$build_file"
grep -Fq 'tdvp_buildroot_command_package' "$build_file"
for command in mkfs.exfat fsck.exfat dump.exfat exfat2img tune.exfat exfatlabel; do
  grep -Fq "$command" "$build_file"
done
for frontend in tdvp-exfat-mkfs tdvp-exfat-fsck tdvp-exfat-dump tdvp-exfat-image tdvp-exfat-tune tdvp-exfat-label; do
  grep -Fq "$frontend" "$build_file"
done
grep -Fq '"/usr/bin/$command" "/bin/$command" "/usr/sbin/$command" "/sbin/$command"' "$repo_root/support/buildroot-command-package.sh"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$build_file"; then
  echo 'exfatprogs build must not import a Debian package or binary' >&2
  exit 1
fi

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, system-tools, nodejs]' "$workflow"
grep -Fq 'exfat-filesystem-tools)' "$workflow"
grep -Fq 'package_args=(--package exfatprogs)' "$workflow"
grep -Fq 'expected_packages=(exfatprogs)' "$workflow"
grep -Fq 'bash ./tests/exfatprogs-package-policy.sh' "$workflow"

echo 'isolated exfatprogs policy: PASS'
