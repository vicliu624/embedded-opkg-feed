#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/ed"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"
expect_line() { local pattern=$1 path=$2 normalized; normalized=$(sed 's/\r$//' "$path"); grep -Eq -- "$pattern" <<<"$normalized" || { echo "missing ed policy entry in $path: $pattern" >&2; exit 1; }; }
expect_line "^PACKAGE='ed'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]20[.]2-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='GNU ed'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='65fec7318f48c2ca17f334ac0f4703defe62037bb13cc23920de077b5fa24523'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_FILE='lzip-1[.]25[.]tar[.]gz'$" "$package_dir/source.lock"
grep -Fq 'ed=tdvp-ed' "$package_dir/build.sh"
if grep -Eq '/usr/(s)?bin/ed|apt|dpkg|debian' "$package_dir/build.sh"; then echo 'ed build must not publish ordinary paths or import Debian inputs' >&2; exit 1; fi
grep -Fq 'line-editor-tools)' "$workflow"
grep -Fq 'package_args=(--package ed)' "$workflow"
grep -Fq 'bash ./tests/ed-package-policy.sh' "$workflow"
echo 'locked private GNU ed policy: PASS'
