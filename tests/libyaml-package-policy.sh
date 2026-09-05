#!/usr/bin/env bash
# Keep LibYAML as one independently owned public runtime ABI.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/libyaml-0"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
owner_map="$repo_root/platforms/tdvp-k230-r1/extra-runtime-owners.tsv"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing LibYAML policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='libyaml-0'$" "$package_dir/package.env"
expect_line "^VERSION='0[.]2[.]5-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='shared-library'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='libyaml'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='0[.]2[.]5'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='yaml-0[.]2[.]5[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='c642ae9b75fee120b2d96c712538bd2cf283228d2337df2cf2988e3c02678ef4'$" "$package_dir/source.lock"
expect_line "BR2_PACKAGE_LIBYAML libyaml 'libyaml-0[.]so[*]' 'LIBYAML_VERSION = 0[.]2[.]5'" "$package_dir/build.sh"
expect_line '^libyaml-0[.]so[.]2[|]libyaml-0[|]0[.]2[.]5-1$' "$owner_map"

grep -Fq 'options: [archive, audacious, network-tools, desktop-tools, retro-gba, development-tools, database-tools, calculator-tools, coreutils-tools, fat-media-tools, fat-filesystem-tools, exfat-filesystem-tools, memory-diagnostic-tools, yaml-runtime, system-tools, nodejs]' "$workflow"
grep -Fq 'yaml-runtime)' "$workflow"
grep -Fq 'package_args=(--package libyaml-0)' "$workflow"
grep -Fq 'expected_packages=(libyaml-0)' "$workflow"
grep -Fq 'bash ./tests/libyaml-package-policy.sh' "$workflow"
grep -Fq 'Refresh source-built runtime owners in this private candidate' "$workflow"
grep -Fq 'scripts/refresh-extra-runtime-owners.sh' "$workflow"
if grep -Fq "platforms/tdvp-k230-r1/*.tsv" "$workflow"; then
  echo 'target-runtime cache must not hash the mutable source-owner manifest' >&2
  exit 1
fi

echo 'source-built LibYAML shared-runtime provider policy: PASS'
