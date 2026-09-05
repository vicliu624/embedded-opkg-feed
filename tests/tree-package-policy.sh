#!/usr/bin/env bash
# Keep the directory-tree candidate a single isolated command package.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/tree"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing tree candidate policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='tree'$" "$package_dir/package.env"
expect_line "^VERSION='2[.]1[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='tree=tdvp-tree'" "$package_dir/build.sh"
expect_line "BR2_PACKAGE_TREE tree 'TREE_VERSION = 2[.]1[.]1' 'tree'" "$package_dir/build.sh"
expect_line "^UPSTREAM_NAME='tree'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_URL='https://archive[.]ubuntu[.]com/ubuntu/pool/universe/t/tree/tree_2[.]1[.]1[.]orig[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='d3c3d55f403af7c76556546325aa1eca90b918cbaaf6d3ab60a49d8367ab90d5'$" "$package_dir/source.lock"

grep -Fq 'directory-tree-tools' "$workflow"
grep -Fq 'package_args=(--package tree)' "$workflow"
grep -Fq 'expected_packages=(tree)' "$workflow"
grep -Fq 'bash ./tests/tree-package-policy.sh' "$workflow"

echo 'source-built directory-tree candidate policy: PASS'
