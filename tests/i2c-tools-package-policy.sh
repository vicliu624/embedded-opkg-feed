#!/usr/bin/env bash
# Lock the i2c-tools candidate to a static, command-only boundary.
set -Eeuo pipefail
IFS=$'\n\t'

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
package_dir="$repo_root/packages/i2c-tools"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing i2c-tools policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='i2c-tools'$" "$package_dir/package.env"
expect_line "^VERSION='4[.]4-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_BUILD_DEPENDS=''$" "$package_dir/package.env"
expect_line "^PACKAGE_AUTO_RUNTIME_DEPENDS=1$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
expect_line "^UPSTREAM_NAME='i2c-tools'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='i2c-tools-4[.]4[.]tar[.]xz'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_SHA256='8b15f0a880ab87280c40cfd7235cfff28134bf14d5646c07518b1ff6642a2473'$" "$package_dir/source.lock"

grep -Fq "TDVP_COMMAND_BUILDROOT_DISABLE_SYMBOLS='BR2_PACKAGE_PYTHON3'" "$package_dir/build.sh"
grep -Fq 'I2C_TOOLS_MAKE_OPTS=BUILD_DYNAMIC_LIB=0 BUILD_STATIC_LIB=1 USE_STATIC_LIB=1' "$package_dir/build.sh"
grep -Fq 'i2cdetect=tdvp-i2c-detect' "$package_dir/build.sh"
grep -Fq 'i2cdump=tdvp-i2c-dump' "$package_dir/build.sh"
grep -Fq 'i2cset=tdvp-i2c-set' "$package_dir/build.sh"
grep -Fq 'i2cget=tdvp-i2c-get' "$package_dir/build.sh"
grep -Fq 'i2ctransfer=tdvp-i2c-transfer' "$package_dir/build.sh"
grep -Fq "'i2cdetect i2cdump i2cset i2cget i2ctransfer'" "$package_dir/build.sh"
if grep -Eq 'i2c-stub-from-dump|eeprog|/usr/(s)?bin/i2c|apt|dpkg|debian' "$package_dir/build.sh"; then
  echo 'i2c-tools build must not publish ordinary paths or include extra tools/debian inputs' >&2
  exit 1
fi

# A nested assignment stays a single make argument and is never evaluated by
# a shell. This is required to force i2c-tools' BUILD_DYNAMIC_LIB branch.
grep -Fq '^[A-Z][A-Z0-9_]*=[A-Za-z0-9_./:+=\ -]*$' "$repo_root/support/buildroot-command-package.sh"
grep -Fq '^[A-Z][A-Z0-9_]*=[A-Za-z0-9_./:+=\ -]*$' "$repo_root/support/buildroot-feed-session.sh"
grep -Fq 'i2c-inspection-tools)' "$workflow"
grep -Fq 'package_args=(--package i2c-tools)' "$workflow"
grep -Fq 'expected_packages=(i2c-tools)' "$workflow"
grep -Fq 'bash ./tests/i2c-tools-package-policy.sh' "$workflow"

echo 'locked static i2c-tools policy: PASS'
