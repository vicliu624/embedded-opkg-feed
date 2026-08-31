#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
for package in git git-runtime; do
  grep -Fqx "PACKAGE='$package'" "$repo_root/packages/$package/package.env"
  grep -Fqx "PACKAGE_RELEASES='r9 r10'" "$repo_root/packages/$package/package.env"
done
grep -Fq "PACKAGE_DEPENDS='git-runtime (= 2.48.1-1), ca-certificates (= 2025.02.1-1)'" "$repo_root/packages/git/package.env"
grep -Fq 'BR2_PACKAGE_OPENSSL BR2_PACKAGE_LIBCURL BR2_PACKAGE_CA_CERTIFICATES BR2_PACKAGE_OPENSSH_CLIENT' "$repo_root/packages/git-runtime/build.sh"
grep -Fq 'usr/libexec/git-core' "$repo_root/packages/git-runtime/build.sh"
grep -Fq 'usr/share/git-core' "$repo_root/packages/git-runtime/build.sh"
if grep -Eq 'cp .*usr/lib/' "$repo_root/packages/git/build.sh"; then
  echo 'Git frontend must not embed a dynamic runtime library' >&2
  exit 1
fi
