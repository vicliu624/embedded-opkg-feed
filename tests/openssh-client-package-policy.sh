#!/usr/bin/env bash
# Keep SSH transport client-only, source-built, and separate from firmware
# SSH server configuration before Git may depend on it.
set -Eeuo pipefail
IFS=$'\n\t'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$script_dir/.." && pwd)
package_dir="$repo_root/packages/openssh-client"
workflow="$repo_root/.github/workflows/build-r10-batch-candidate.yml"

expect_line() {
  local pattern=$1 path=$2 normalized
  normalized=$(sed 's/\r$//' "$path")
  grep -Eq -- "$pattern" <<<"$normalized" || {
    echo "missing OpenSSH client policy entry in $path: $pattern" >&2
    exit 1
  }
}

expect_line "^PACKAGE='openssh-client'$" "$package_dir/package.env"
expect_line "^VERSION='9[.]9p2-1'$" "$package_dir/package.env"
expect_line "^PACKAGE_KIND='application'$" "$package_dir/package.env"
expect_line "^PACKAGE_BASE_OVERLAY='identical'$" "$package_dir/package.env"
expect_line "^PACKAGE_DEPENDS='libssl-3 \\(= 3[.]4[.]1-1\\), libcrypto-3 \\(= 3[.]4[.]1-1\\), libz \\(= 1[.]3[.]1-1\\)'$" "$package_dir/package.env"
test -f "$package_dir/source.lock"
expect_line "^UPSTREAM_NAME='OpenSSH portable'$" "$package_dir/source.lock"
expect_line "^UPSTREAM_VERSION='9[.]9p2'$" "$package_dir/source.lock"
expect_line "^SOURCE_TYPE='release-tarball'$" "$package_dir/source.lock"
expect_line "^SOURCE_ARTIFACT_1_FILE='openssh-9[.]9p2[.]tar[.]gz'$" "$package_dir/source.lock"
expect_line 'matching SDK compiler/sysroot' "$package_dir/source.lock"
expect_line 'openssh-client must not package /etc/ssh' "$package_dir/build.sh"
expect_line tdvp_remove_elf_runtime_search_paths "$package_dir/build.sh"
expect_line 'identical-overlay policy' "$package_dir/build.sh"
expect_line 'required_paths=\(ssh scp sftp ssh-agent ssh-add\)' "$package_dir/build.sh"

grep -Fq 'secure-transfer-tools)' "$workflow"
grep -Fq 'package_args=(--package openssh-client)' "$workflow"
grep -Fq 'expected_packages=(openssh-client)' "$workflow"
grep -Fq 'bash ./tests/openssh-client-package-policy.sh' "$workflow"

echo 'source-built client-only OpenSSH transport policy: PASS'
