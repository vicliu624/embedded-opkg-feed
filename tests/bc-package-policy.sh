#!/usr/bin/env bash
# Keep GNU bc an independently source-built, prefixed calculator command.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/bc"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing GNU bc policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='bc'$" "$package_dir/package.env"
expect_line "^VERSION='1[.]07[.]1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='GNU bc'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='bc-1[.]07[.]1[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='62adfca89b0a1c0164c2cdca59ca210c1d44c3ffc46daf9931cf4942664cb02a'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_FILE='flex-2[.]6[.]4[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_2_SHA256='e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_3_FILE='m4-1[.]4[.]19[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_3_SHA256='63aede5c6d33b6d9b13511cd0be2cac046f2e70fd0a07aa9573a04a82783af96'$" "$package_dir/source.lock"
expect_line "TDVP_COMMAND_FRONTEND_NAMES='bc=tdvp-bc'" "$package_dir/build.sh"
expect_line "BR2_PACKAGE_BC bc 'BC_VERSION = 1[.]07[.]1' 'bc'" "$package_dir/build.sh"
grep -Fq 'calculator-tools)' "$workflow"
grep -Fq 'package_args=(--package bc)' "$workflow"
grep -Fq 'expected_packages=(bc)' "$workflow"
grep -Fq 'bash ./tests/bc-package-policy.sh' "$workflow"
if grep -Eq '(^|[^A-Za-z0-9_])(apt|dpkg|debian)([^A-Za-z0-9_]|$)' "$package_dir/build.sh"; then
  echo 'GNU bc build must not import a Debian package or binary' >&2
  exit 1
fi

echo 'GNU bc source-built calculator policy: PASS'
