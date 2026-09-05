#!/usr/bin/env bash
# Keep the shared TLS trust store source-built and self-contained.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/ca-certificates"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing CA certificate policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='ca-certificates'$" "$package_dir/package.env"
expect_line "^VERSION='2025\\.02\\.1-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='runtime'$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='deny'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='Debian ca-certificates'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='20230311'$" "$package_dir/source.lock"
expect_line "CA_CERTIFICATES_VERSION = 20230311" "$package_dir/build.sh"
expect_line 'tdvp_prepare_locked_buildroot_download' "$package_dir/build.sh"
expect_line 'offline-download-dir' "$package_dir/build.sh"
expect_line 'certificate_source=.*usr/share/ca-certificates' "$package_dir/build.sh"
expect_line 'ca-certificates[.]crt' "$package_dir/build.sh"
expect_line 'c_rehash' "$package_dir/build.sh"
expect_line 'refusing to replace non-generated payload path' "$package_dir/build.sh"

grep -Fq 'trust-store-runtime)' "$workflow"
grep -Fq 'package_args=(--package ca-certificates)' "$workflow"
grep -Fq 'expected_packages=(ca-certificates)' "$workflow"
grep -Fq 'bash ./tests/ca-certificates-package-policy.sh' "$workflow"

echo 'source-built CA certificate bundle and ownership policy: PASS'
